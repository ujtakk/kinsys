`include "renkon.svh"

module linebuf
  ( input                      clk
  , input                      xrst
  , input                      buf_en
  , input         [LWIDTH-1:0] img_size
  , input         [LWIDTH-1:0] fil_size
  , input  signed [DWIDTH-1:0] buf_input
  , output signed [DWIDTH-1:0] buf_output [MAXLINE**2-1:0]
  );

  localparam BUFSIZE = ;
  localparam MAXLINE = ;

  wire               s_charge_end;
  wire               s_active_end;
  wire [8-1:0]       mem_linebuf_we;
  wire [BUFSIZE-1:0] mem_linebuf_addr;

  enum reg [2-1:0] {
    S_WAIT, S_CHARGE, S_ACTIVE
  } r_state;
  reg        [4-1:0]       r_select;
  reg        [BUFSIZE-1:0] r_addr_count;
  reg        [3-1:0]       r_mem_count;
  reg        [LWIDTH-1:0]  r_line_count;
  reg        [8-1:0]       r_linebuf_we;
  reg signed [DWIDTH-1:0]  r_pixel [MAXLINE**2-1:0];

  assign mem_linebuf_addr = r_addr_count;

  assign mem_linebuf_we = (r_state == S_CHARGE || r_state == S_ACTIVE)
                        ? (1 << r_mem_count)
                        : 1'b0;

  for (genvar i = 0; i < MAXLINE**2; i++)
    assign buf_output[i] = r_pixel[i];

  always @(posedge clk or negedge xrst)
    if (!xrst)
      r_state <= S_WAIT;
    else
      case (r_state)
        S_WAIT:
          if (buf_en)
            r_state <= S_CHARGE;
        S_CHARGE:
          if (s_charge_end)
            r_state <= S_ACTIVE;
        S_ACTIVE:
          if (s_active_end)
            r_state <= S_WAIT;
        default:
          r_state <= S_WAIT;
      endcase

  assign s_charge_end = r_mem_count == fil_size - 1
                        && r_addr_count == img_size - 1;

  assign s_active_end = r_line_count == img_size
                        && r_addr_count == img_size - 1;

  always @(posedge clk or negedge xrst)
    if (!xrst)
      r_buf_input <= 0;
    else
      r_buf_input <= buf_input;

  always @(posedge clk or negedge xrst)
    if (!xrst)
      r_addr_count <= 0;
    else if (r_state == S_WAIT)
      r_addr_count <= 0;
    else if (r_state == S_CHARGE || r_state == S_ACTIVE)
      if (r_addr_count == img_size - 1)
        r_addr_count <= 0;
      else
        r_addr_count <= r_addr_count + 1;

  always @(posedge clk or negedge xrst)
    if (!xrst)
      r_mem_count <= 0;
    else if  (r_state == S_WAIT)
      r_mem_count <= 0;
    else if (r_state == S_CHARGE || r_state == S_ACTIVE)
      if ((r_line_count == img_size || r_mem_count == MAXLINE)
            && r_addr_count == img_size - 1)
        r_mem_count <= 0;
      else if (r_addr_count == img_size - 1)
        r_mem_count <= r_mem_count + 1;

  always @(posedge clk or negedge xrst)
    if (!xrst)
      r_line_count <= 0;
    else if  (r_state == S_WAIT)
      r_line_count <= 0;
    else if (r_state == S_CHARGE || r_state == S_ACTIVE)
      if (r_line_count == img_size && r_addr_count == img_size - 1)
        r_line_count <= 0;
      else if (r_addr_count == img_size - 1)
        r_line_count <= r_line_count + 1;

  always @(posedge clk)
    if (!xrst)
      r_select <= 0;
    else if (r_state == S_WAIT)
      r_select <= 0;
    else if (r_state == S_ACTIVE)
      if (r_mem_count == fil_size && r_addr_count == 0)
        r_select <= 1;
      else if (r_addr_count == 0)
        r_select <= r_select+1;

  for (genvar i = 0; i < MAXLINE; i++)
    for (genvar j = 0; j < MAXLINE; j++)
      if (j == 4)
        for (genvar k = 0; k <= MAXLINE; k++)
          if (k == 0)
            always @(posedge clk)
              if (!xrst)
                r_pixel[MAXLINE * i + j] <= 0;
              else if (r_select == 0)
                r_pixel[MAXLINE * i + j] <= 0;
          else
            always @(posedge clk)
              if (!xrst)
                r_pixel[MAXLINE * i + j] <= 0;
              else if (r_select == k+1)
                r_pixel[MAXLINE * i + j] <= read_mem[(i + k) % (MAXLINE + 1)];
      else
        always @(posedge clk)
          if (!xrst)
            r_pixel[MAXLINE * i + j] <= 0;
          else
            r_pixel[MAXLINE * i + j] <= r_pixel[MAXLINE * i + (j+1)];

  for (genvar i = 0; i < MAXLINE+1; i++)
    mem_sp #(DWIDTH, BUFSIZE) mem_buf(
      .mem_we     (mem_linebuf_we[i]),
      .mem_addr   (mem_linebuf_addr),
      .write_data (r_buf_input),
      .read_data  (read_mem[i]),
      .*
    );

endmodule
