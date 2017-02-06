`include "renkon.svh"
`include "ctrl_bus.svh"

module ctrl_core
  ( input                       clk
  , input                       xrst
  , ctrl_bus.in                 in_ctrl
  , input                       req
  , input                       img_we
  , input         [IMGSIZE-1:0] input_addr
  , input         [IMGSIZE-1:0] output_addr
  , input  signed [DWIDTH-1:0]  write_img
  , input  signed [DWIDTH-1:0]  write_result
  , input         [CORELOG:0]   net_we
  , input         [NETSIZE-1:0] net_addr
  , input         [LWIDTH-1:0]  total_out
  , input         [LWIDTH-1:0]  total_in
  , input         [LWIDTH-1:0]  img_size
  , input         [LWIDTH-1:0]  fil_size
  , ctrl_bus.out                out_ctrl
  , output                      ack
  , output        [2-1:0]       core_state
  , output                      mem_img_we
  , output        [IMGSIZE-1:0] mem_img_addr
  , output signed [DWIDTH-1:0]  write_mem_img
  , output        [CORE-1:0]    mem_net_we
  , output        [NETSIZE-1:0] mem_net_addr
  , output                      buf_pix_en
  , output                      first_input
  , output                      last_input
  , output                      wreg_we
  , output                      breg_we
  , output                      serial_we
  , output        [CORELOG:0]   serial_re
  , output        [OUTSIZE-1:0] serial_addr
  , output        [LWIDTH-1:0]  w_img_size
  , output        [LWIDTH-1:0]  w_fil_size
  );

  wire               s_network_end;
  wire               s_input_end;
  wire               s_output_end;
  wire               s_w_weight_end;
  wire               s_w_bias_end;
  wire               final_iter;
  wire [IMGSIZE-1:0] w_img_addr;
  wire [IMGSIZE-1:0] w_img_offset;

  enum reg [2-1:0] {
    S_WAIT, S_NETWORK, S_INPUT, S_OUTPUT
  } r_state;
  enum reg {
    S_W_WEIGHT, S_W_BIAS
  } r_state_weight;
  reg               r_ack;
  reg [LWIDTH-1:0]  r_total_out;
  reg [LWIDTH-1:0]  r_total_in;
  reg [LWIDTH-1:0]  r_img_size;
  reg [LWIDTH-1:0]  r_fil_size;
  reg [LWIDTH-1:0]  r_pool_size;
  reg [LWIDTH-1:0]  r_count_out;
  reg [LWIDTH-1:0]  r_count_in;
  reg [LWIDTH-1:0]  r_input_x;
  reg [LWIDTH-1:0]  r_input_y;
  reg [LWIDTH-1:0]  r_weight_x;
  reg [LWIDTH-1:0]  r_weight_y;
  reg [LWIDTH-1:0]  r_d_pixelbuf;
  reg               r_buf_pix_en;
  reg               r_img_we;
  reg               r_out_we;
  reg [IMGSIZE-1:0] r_input_offset;
  reg [IMGSIZE-1:0] r_output_offset;
  reg [IMGSIZE-1:0] r_input_addr;
  reg [IMGSIZE-1:0] r_output_addr;
  reg [CORE-1:0]    r_net_we;
  reg [NETSIZE-1:0] r_net_addr;
  reg [NETSIZE-1:0] r_net_offset;
  reg               r_serial_we;
  reg [CORELOG:0]   r_serial_re;
  reg [LWIDTH-1:0]  r_serial_cnt;
  reg [OUTSIZE-1:0] r_serial_addr;
  reg               r_serial_end;
  reg               r_output_end;
  reg [2-1:0]       r_state_d         [D_PIXELBUF:0];
  reg               r_state_weight_d  [D_PIXELBUF:0];
  reg               r_wreg_we_d       [D_PIXELBUF-1:0];
  reg               r_first_input_d   [D_PIXELBUF-1:0];
  reg               r_last_input_d    [D_PIXELBUF-1:0];
  reg               r_out_begin_d     [D_PIXELBUF-1:0];
  reg               r_out_valid_d     [D_PIXELBUF-1:0];
  reg               r_out_end_d       [D_PIXELBUF-1:0];

//==========================================================
// core control
//==========================================================

  assign final_iter = r_count_in == r_total_in - 1
                   && r_count_out + CORE >= r_total_out;

  //main FSM
  always @(posedge clk)
    if (!xrst) begin
      r_state     <= S_WAIT;
      r_count_in  <= 0;
      r_count_out <= 0;
    end
    else
      case (r_state)
        S_WAIT:
          if (req)
            r_state <= S_NETWORK;
        S_NETWORK:
          if (s_network_end)
            r_state <= S_INPUT;
        S_INPUT:
          if (s_input_end)
            if (r_count_in == r_total_in - 1) begin
              r_state     <= S_OUTPUT;
              r_count_in  <= 0;
            end
            else begin
              r_state     <= S_NETWORK;
              r_count_in  <= r_count_in + 1;
            end
        S_OUTPUT:
          if (s_output_end)
            if (r_count_out + CORE >= r_total_out) begin
              r_state     <= S_WAIT;
              r_count_out <= 0;
            end
            else begin
              r_state     <= S_NETWORK;
              r_count_out <= r_count_out + CORE;
            end
      endcase

  assign core_state = r_state_d[r_d_pixelbuf];

  <%- for i in 0..$d_pixelbuf -%>
  always @(posedge clk)
    <%- if i == 0 -%>
    if (!xrst)
      r_state_d[<%=i%>] <= 0;
    <%- elsif i == 1 -%>
    if (!xrst)
      r_state_d[<%=i%>] <= 0;
    else
      r_state_d[<%=i%>] <= r_state;
    <%- else -%>
    if (!xrst)
      r_state_d[<%=i%>] <= 0;
    else
      r_state_d[<%=i%>] <= r_state_d[<%=i-1%>];
    <%- end -%>
  <%- end -%>

  assign w_img_size = r_img_size;
  assign w_fil_size = r_fil_size;

  //wait exec (initialize)
  always @(posedge clk)
    if (!xrst) begin
      r_total_in    <= 0;
      r_total_out   <= 0;
      r_img_size    <= 0;
      r_fil_size    <= 0;
      r_d_pixelbuf  <= 0;
    end
    else if (r_state == S_WAIT && req) begin
      r_total_in    <= total_in;
      r_total_out   <= total_out;
      r_img_size    <= img_size;
      r_fil_size    <= fil_size;
      r_d_pixelbuf  <= img_size - fil_size + 8 - 1;
    end

  assign first_input = r_first_input_d[r_d_pixelbuf];
  assign last_input  = r_last_input_d[r_d_pixelbuf];

  for (genvar i = 0; i < D_PIXELBUF; i++)
    if (i == 0)
      always @(posedge clk)
        if (!xrst)
        else
    else
      always @(posedge clk)
        if (!xrst)
        else

  <%- for i in 0...$d_pixelbuf -%>
  always @(posedge clk)
    <%- if i == 0 -%>
    if (!xrst) begin
      r_first_input_d[0] <= 0;
      r_last_input_d[0]  <= 0;
    end
    else begin
      r_first_input_d[0] <= r_state == S_INPUT && r_count_in == 0;
      r_last_input_d[0]  <= r_state == S_INPUT && r_count_in == r_total_in - 1;
    end
    <%- else -%>
    if (!xrst) begin
      r_first_input_d[<%=i%>] <= 0;
      r_last_input_d[<%=i%>]  <= 0;
    end
    else begin
      r_first_input_d[<%=i%>] <= r_first_input_d[<%=i-1%>];
      r_last_input_d[<%=i%>]  <= r_last_input_d[<%=i-1%>];
    end
    <%- end -%>
  <%- end -%>

//==========================================================
// network control
//==========================================================

  assign mem_net_we   = r_net_we;
  assign mem_net_addr = r_net_addr + r_net_offset;

  assign s_network_end  = r_state == S_NETWORK && r_count_in == r_total_in - 1
                        ? s_w_bias_end
                        : s_w_weight_end;

  assign s_w_weight_end = r_state_weight == S_W_WEIGHT
                       && r_weight_x == r_fil_size - 1
                       && r_weight_y == r_fil_size - 1;

  assign s_w_bias_end   = r_state_weight == S_W_BIAS;

  always @(posedge clk)
    if (!xrst)
      r_state_weight <= S_W_WEIGHT;
    else
      case (r_state_weight)
        S_W_WEIGHT:
          if (s_w_weight_end && r_count_in == r_total_in - 1)
            r_state_weight <= S_W_BIAS;
        S_W_BIAS:
          if (s_w_bias_end)
            r_state_weight <= S_W_WEIGHT;
        default:
          r_state_weight <= S_W_WEIGHT;
      endcase

  always @(posedge clk)
    if (!xrst)
      r_net_we <= 0;
    else
      case (net_we)
        <%- for i in 0..$core -%>
        <%=$core_log+1%>'d<%=i%>:
          r_net_we <= <%=$core%>'b<%=sprintf("%0#{$core}b", 1<<(i-1))%>;
        <%- end -%>
        default:
          r_net_we <= <%=$core%>'b<%=sprintf("%0#{$core}b", 0)%>;
      endcase

  <%- for i in 1..$d_pixelbuf -%>
  always @(posedge clk)
    <%- if i == 1 -%>
    if (!xrst)
      r_state_weight_d[<%=i%>] <= 0;
    else
      r_state_weight_d[<%=i%>] <= r_state_weight;
    <%- else -%>
    if (!xrst)
      r_state_weight_d[<%=i%>] <= 0;
    else
      r_state_weight_d[<%=i%>] <= r_state_weight_d[<%=i-1%>];
    <%- end -%>
  <%- end -%>

  always @(posedge clk)
    if (!xrst)
      r_net_addr <= 0;
    else if (final_iter && r_state_weight_d[r_d_pixelbuf] == S_W_BIAS)
      r_net_addr <= 0;
    else if (r_state_d[r_d_pixelbuf] == S_NETWORK)
      case (r_state_weight_d[r_d_pixelbuf])
        S_W_WEIGHT:
          r_net_addr <= r_net_addr + 1;
        S_W_BIAS:
          r_net_addr   <= r_net_addr + 1;
        default:
          r_net_addr <= r_net_addr;
      endcase

  always @(posedge clk)
    if (!xrst)
      r_net_offset <= 0;
    else if (req || ack)
      r_net_offset <= net_addr;

  always @(posedge clk)
    if (!xrst) begin
      r_weight_x <= 0;
      r_weight_y <= 0;
    end
    else
      case (r_state)
        S_NETWORK:
          case (r_state_weight)
            S_W_WEIGHT:
              if (r_weight_x == r_fil_size - 1) begin
                r_weight_x <= 0;
                if (r_weight_y == r_fil_size - 1)
                  r_weight_y <= 0;
                else
                  r_weight_y <= r_weight_y + 1;
              end
              else
                r_weight_x <= r_weight_x + 1;
            default: begin
              r_weight_x <= 0;
              r_weight_y <= 0;
            end
          endcase
        default: begin
          r_weight_x <= 0;
          r_weight_y <= 0;
        end
      endcase

//==========================================================
// params control
//==========================================================

  assign wreg_we  = r_state_d[r_d_pixelbuf+1] == S_NETWORK
                 && r_state_weight_d[r_d_pixelbuf+1] == S_W_WEIGHT;

  assign breg_we  = r_state_d[r_d_pixelbuf+1] == S_NETWORK
                 && r_state_weight_d[r_d_pixelbuf+1] == S_W_BIAS;

  assign buf_pix_en = r_buf_pix_en;

  always @(posedge clk)
    if (!xrst)
      r_buf_pix_en <= 0;
    else
      r_buf_pix_en <= r_state == S_INPUT
                   && r_out_begin_d[0];

//==========================================================
// input control
//==========================================================

  assign s_input_end  = r_state == S_INPUT
                     && r_input_x == r_img_size - 1
                     && r_input_y == r_img_size - 1;

  assign mem_img_we   = r_img_we;
  assign mem_img_addr = w_img_addr + w_img_offset;

  assign write_mem_img = r_state == S_OUTPUT
                       ? write_result
                       : write_img;

  assign w_img_addr = r_state == S_OUTPUT
                    ? r_output_addr
                    : r_input_addr;

  assign w_img_offset = r_state == S_OUTPUT
                      ? r_output_offset
                      : r_input_offset;

  always @(posedge clk)
    if (!xrst) begin
      r_input_x <= 0;
      r_input_y <= 0;
    end
    else
      case (r_state)
        S_INPUT:
          if (r_input_x == r_img_size - 1) begin
            r_input_x <= 0;
            if (r_input_y == r_img_size - 1)
              r_input_y <= 0;
            else
              r_input_y <= r_input_y + 1;
          end
          else
            r_input_x <= r_input_x + 1;
        default: begin
          r_input_x <= 0;
          r_input_y <= 0;
        end
    endcase

  always @(posedge clk)
    if (!xrst)
      r_img_we <= 0;
    else
      case (r_state)
        S_WAIT:
          r_img_we <= img_we;
        S_OUTPUT:
          r_img_we <= r_out_we;
        default:
          r_img_we <= 0;
      endcase

  always @(posedge clk)
    if (!xrst)
      r_input_addr <= 0;
    else if (r_state == S_OUTPUT)
      r_input_addr <= 0;
    else if (r_state == S_INPUT)
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
      r_input_offset <= 0;
      r_output_offset <= 0;
    end
    else if (req || ack) begin
      r_input_offset <= input_addr;
      r_output_offset <= output_addr;
    end

//==========================================================
// output control
//==========================================================

  assign ack          = r_ack;

  assign serial_we    = r_serial_we;
  assign serial_re    = r_serial_re;
  assign serial_addr  = r_serial_addr;

  assign out_begin    = r_out_begin_d[r_d_pixelbuf];
  assign out_valid    = r_out_valid_d[r_d_pixelbuf];
  assign out_end      = r_out_end_d[r_d_pixelbuf];

  assign s_output_end = r_output_end;

  always @(posedge clk)
    if (!xrst)
      r_serial_end <= 0;
    else
      r_serial_end <= r_serial_re == CORE
                   && r_serial_addr == r_serial_cnt - 1;

  always @(posedge clk)
    if (!xrst)
      r_output_end <= 0;
    else
      r_output_end <= r_state == S_OUTPUT && r_serial_end;

  always @(posedge clk)
    if (!xrst)
      r_out_we <= 0;
    else
      r_out_we <= r_serial_re > 0;

  always @(posedge clk)
    if (!xrst)
      r_ack <= 1;
    else if (req)
      r_ack <= 0;
    else if (s_output_end && r_count_out + CORE >= r_total_out)
      r_ack <= 1;

  always @(posedge clk)
    if (!xrst)
      r_serial_we <= 0;
    else if (r_state == S_OUTPUT)
      if (in_begin)
        r_serial_we <= 1;
      else if (in_end)
        r_serial_we <= 0;

  always @(posedge clk)
    if (!xrst)
      r_serial_re <= 0;
    else if (in_end)
      r_serial_re <= 1;
    else if (r_serial_re > 0 && r_serial_addr == r_serial_cnt - 1)
      if (r_serial_re == CORE)
        r_serial_re <= 0;
      else
        r_serial_re <= r_serial_re + 1;

  always @(posedge clk)
    if (!xrst)
      r_serial_cnt <= 0;
    else if (s_output_end)
      r_serial_cnt <= 0;
    else if (r_state == S_OUTPUT && in_valid)
      r_serial_cnt <= r_serial_cnt + 1;

  always @(posedge clk)
    if (!xrst)
      r_serial_addr <= 0;
    else if (s_output_end)
      r_serial_addr <= 0;
    else if (r_state == S_OUTPUT && in_valid)
      if (in_end)
        r_serial_addr <= 0;
        else
        r_serial_addr <= r_serial_addr + 1;
    else if (r_serial_re > 0)
      if (r_serial_addr == r_serial_cnt - 1)
        r_serial_addr <= 0;
      else
        r_serial_addr <= r_serial_addr + 1;

  <%- for n in ["begin", "valid", "end"] -%>
  <%-   for i in 0...$d_pixelbuf -%>
  always @(posedge clk)
    <%- if i == 0 -%>
    if (!xrst)
      r_out_<%=n%>_d[0] <= 0;
    else
      <%- case n -%>
      <%- when "begin" -%>
      r_out_begin_d[0] <= req
                       || s_network_end
                       || s_input_end
                          && r_count_in != r_total_in - 1;
      <%- when "valid" -%>
      r_out_valid_d[0] <= r_state == S_NETWORK || r_state == S_INPUT;
      <%- when "end" -%>
      r_out_end_d[0]   <= s_network_end || s_input_end;
      <%- else -%>
      <%- end -%>
    <%- else -%>
    if (!xrst)
      r_out_<%=n%>_d[<%=i%>] <= 0;
    else
      r_out_<%=n%>_d[<%=i%>] <= r_out_<%=n%>_d[<%=i-1%>];
    <%- end -%>
  <%-   end -%>
  <%- end -%>

endmodule