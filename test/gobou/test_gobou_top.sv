`include "gobou.svh"
`include "ninjin.svh"

// `define SAIF
// `define NINJIN
`define DIRECT

int N_IN  = 512;
int N_OUT = 128;
// int N_IN  = 512 * 7 * 7;
// int N_OUT = 4096;
int QBITS = 8;

int IMG_OFFSET = 0;
int OUT_OFFSET = N_IN+1;
int NET_OFFSET = 0;

int DO_BIAS = 1;
int DO_RELU = 1;

module test_gobou_top;

  reg                     clk;
  reg                     xrst;
  reg                     req;
  reg [GOBOU_CORELOG-1:0] net_sel;
  reg                     net_we;
  reg [GOBOU_NETSIZE-1:0] net_addr;
  reg signed [DWIDTH-1:0] net_wdata;
  reg [MEMSIZE-1:0]       in_offset;
  reg [MEMSIZE-1:0]       out_offset;
  reg [GOBOU_NETSIZE-1:0] net_offset;
  reg [DWIDTHLOG-1:0]     qbits;
  reg [LWIDTH-1:0]        total_out;
  reg [LWIDTH-1:0]        total_in;
  reg                     bias_en;
  reg                     relu_en;

  wire                    ack;

  reg                      img_we;
  reg [MEMSIZE-1:0]        img_addr;
  reg signed [DWIDTH-1:0]  img_wdata;

  wire                      mem_img_we;
  wire [MEMSIZE-1:0]        mem_img_addr;
  wire signed [DWIDTH-1:0]  mem_img_wdata;
  wire signed [DWIDTH-1:0]  mem_img_rdata;

  wire                      gobou_img_we;
  wire [MEMSIZE-1:0]        gobou_img_addr;
  wire signed [DWIDTH-1:0]  gobou_img_wdata;
  wire signed [DWIDTH-1:0]  gobou_img_rdata;

  bit signed [DWIDTH-1:0] mem_i [2**MEMSIZE-1:0];
  bit signed [DWIDTH-1:0] mem_n [GOBOU_CORE-1:0][2**GOBOU_NETSIZE-1:0];

  int req_time = 2**30;
  int now_time = 0;

  assign mem_img_we     = ack ? img_we    : gobou_img_we;
  assign mem_img_addr   = ack ? img_addr  : gobou_img_addr;
  assign mem_img_wdata  = ack ? img_wdata : gobou_img_wdata;

  assign gobou_img_rdata = mem_img_rdata;

`ifdef NINJIN
/// {{{
  reg                     pre_req;
  reg [WORDSIZE-1:0]      pre_base;
  reg [LWIDTH-1:0]        read_len;
  reg [LWIDTH-1:0]        write_len;
  reg                     ddr_we;
  reg [WORDSIZE-1:0]      ddr_waddr;
  reg [BWIDTH-1:0]        ddr_wdata;
  reg [WORDSIZE-1:0]      ddr_raddr;
  wire                    pre_ack;
  wire                    ddr_req;
  wire                    ddr_mode;
  wire [WORDSIZE+LSB-1:0] ddr_base;
  wire [LWIDTH-1:0]       ddr_len;
  wire [BWIDTH-1:0]       ddr_rdata;
  wire [2-1:0]            probe_state;
  integer _ddr_base [1:0];
  integer _ddr_len [1:0];
  ninjin_ddr_buf mem_img(
    .mem_we     (mem_img_we),
    .mem_addr   (mem_img_addr),
    .mem_wdata  (mem_img_wdata),
    .mem_rdata  (mem_img_rdata),
    .*
  );
  always @(posedge ddr_req) begin
    #(STEP/2-1);
    if (ddr_mode == DDR_READ) begin
      _ddr_base[DDR_READ] = ddr_base;
      _ddr_len[DDR_READ]  = ddr_len;
      #(STEP);
      for (int i = 0; i < _ddr_len[DDR_READ]; i++) begin
        ddr_we    = 1;
        ddr_waddr = i + (_ddr_base[DDR_READ] >> LSB);
        ddr_wdata = {
          mem_i[2*(ddr_waddr-(IMG_OFFSET >> RATELOG))+1],
          mem_i[2*(ddr_waddr-(IMG_OFFSET >> RATELOG))]
        };
        #(STEP);
      end
      ddr_we    = 0;
      ddr_waddr = 0;
      ddr_wdata = 0;
      #(STEP);
    end
    #(STEP/2+1);
  end

  always @(posedge ddr_req) begin
    #(STEP/2-1);
    if (ddr_mode == DDR_WRITE) begin
      _ddr_base[DDR_WRITE] = ddr_base;
      _ddr_len[DDR_WRITE]  = ddr_len;
      #(STEP);
      for (int i = 0; i < _ddr_len[DDR_WRITE]; i++) begin
        ddr_raddr = i + (_ddr_base[DDR_WRITE] >> LSB);
        #(STEP);
      end
      ddr_raddr = 0;
      #(STEP);
    end
    #(STEP/2+1);
  end
// }}}
`else
  mem_sp #(DWIDTH, MEMSIZE) mem_img(
    .mem_we     (mem_img_we),
    .mem_addr   (mem_img_addr),
    .mem_wdata  (mem_img_wdata),
    .mem_rdata  (mem_img_rdata),
    .*
  );
`endif

  gobou_top dut(
    .img_we     (gobou_img_we),
    .img_addr   (gobou_img_addr),
    .img_wdata  (gobou_img_wdata),
    .img_rdata  (gobou_img_rdata),
    .*
  );

`ifdef DIRECT
`ifndef NINJIN
  always @*
    for (int i = 0; i < 2**MEMSIZE; i++)
      if (i < IMG_OFFSET)
        mem_img.mem[i] = 0;
      else
        mem_img.mem[i] = mem_i[i-IMG_OFFSET];
`endif

  // This statement is for direct assignment for generated modules
  for (genvar n = 0; n < GOBOU_CORE; n++)
    always @*
      for (int i = 0; i < 2**GOBOU_NETSIZE; i++)
        if (i < NET_OFFSET)
          dut.pe[n].mem_net.mem[i] = 0;
        else
          dut.pe[n].mem_net.mem[i] = mem_n[n][i-NET_OFFSET];
`endif

  // clock
  initial begin
    clk = 0;
    forever
      #(STEP/2) clk = ~clk;
  end

  // flow
  initial begin
`ifdef SAIF
    $set_toggle_region(test_renkon_top.dut);
`endif

    xrst = 0;
    #(STEP);

    xrst        = 1;
    req         = 0;
    net_sel     = 0;
    net_we      = 0;
    net_addr    = 0;
    net_wdata   = 0;
    in_offset   = IMG_OFFSET;
    out_offset  = OUT_OFFSET;
    net_offset  = NET_OFFSET;
    qbits       = QBITS;
    total_out   = N_OUT;
    total_in    = N_IN;
    bias_en     = DO_BIAS;
    relu_en     = DO_RELU;

    img_we    = 0;
    img_addr  = 0;
    img_wdata = 0;

    mem_clear;
`ifdef DIRECT
    read_input_direct;
    read_params_direct;
`else
    read_input;
    read_params;
`endif

`ifdef NINJIN
    pre_req   = 0;
    pre_base  = 0;
    read_len  = 0;
    write_len = 0;
    ddr_we    = 0;
    ddr_waddr = 0;
    ddr_wdata = 0;
    ddr_raddr = 0;
    #(STEP);

    pre_req   = 1;
    pre_base  = IMG_OFFSET >> RATELOG;
    read_len  = N_IN;
    write_len = GOBOU_CORE;
    #(STEP);
    pre_req = 0;
    #(STEP);

    while (!pre_ack) #(STEP);
    #(STEP);
  `endif
`ifdef SAIF
    $toggle_start();
`endif
    #(STEP);

    req = 1;
    req_time = $time/STEP;
    #(STEP);
    req = 0;

    // while(!ack) #(STEP);
    #(STEP*10000);

    #(STEP*10);

    req_time = 2**30;

`ifdef SAIF
    $toggle_stop();
    $toggle_report(
      $sformatf("gobou%d_%d.saif", label, file),
      1.0e-9,
      "test_gobou_top.dut"
    );
`endif

    write_output;
    $finish();
  end

  task mem_clear;
    begin // {{{
      for (int i = 0; i < 2**MEMSIZE; i++)
        mem_i[i] = 0;

      for (int n = 0; n < GOBOU_CORE; n++)
        for (int i = 0; i < 2**GOBOU_NETSIZE; i++)
          mem_n[n][i] = 0;
    end // }}}
  endtask

  task read_input;
    int idx;
    int fd;
    int r;
    begin // {{{
      idx = 0;
      fd = $fopen("../../data/gobou/input_gobou_top.dat", "r");

      for (int m = 0; m < N_IN; m++) begin
        r = $fscanf(fd, "%x", mem_i[idx]);
        idx++;
      end

      $fclose(fd);
      #(STEP);

      for (int i = 0; i < 2**MEMSIZE; i++) begin
        img_we    = 1;
        img_addr  = i;
        img_wdata = mem_i[i];
        #(STEP);
      end

      img_we    = 0;
      img_addr  = 0;
      img_wdata = 0;
      #(STEP);
    end // }}}
  endtask

  task read_input_direct;
    int idx;
    int fd;
    int r;
    begin // {{{
      idx = 0;
      fd = $fopen("../../data/gobou/input_gobou_top.dat", "r");

      for (int m = 0; m < N_IN; m++) begin
        r = $fscanf(fd, "%x", mem_i[idx]);
        idx++;
      end

      $fclose(fd);
    end // }}}
  endtask

  task read_params;
    int idx[GOBOU_CORE-1:0];
    int wd, bd;
    int r;
    begin // {{{
      for (int dn = 0; dn < GOBOU_CORE; dn++)
        idx[dn] = 0;
      wd = $fopen("../../data/gobou/weight_gobou_top.dat", "r");
      bd = $fopen("../../data/gobou/bias_gobou_top.dat", "r");

      // reading iterations for normal weight sets
      for (int n = 0; n < N_OUT/GOBOU_CORE; n++)
        for (int dn = 0; dn < GOBOU_CORE; dn++) begin
          for (int m = 0; m < N_IN; m++) begin
            r = $fscanf(wd, "%x", mem_n[dn][idx[dn]]);
            idx[dn]++;
          end
          r = $fscanf(bd, "%x", mem_n[dn][idx[dn]]);
          idx[dn]++;
        end

      // reading iteration for a boundary weight set (if exists)
      if (N_OUT % GOBOU_CORE != 0)
        for (int dn = 0; dn < GOBOU_CORE; dn++) begin
          // put remainder weights to cores
          if ((GOBOU_CORE * (N_OUT/GOBOU_CORE) + dn) < N_OUT) begin
            for (int m = 0; m < N_IN; m++) begin
              r = $fscanf(wd, "%x", mem_n[dn][idx[dn]]);
              idx[dn]++;
            end
            r = $fscanf(bd, "%x", mem_n[dn][idx[dn]]);
            idx[dn]++;
          end
          // put null (zero) values to unused cores
          else begin
            for (int m = 0; m < N_IN; m++) begin
              mem_n[dn][idx[dn]] = 0;
              idx[dn]++;
            end
            mem_n[dn][idx[dn]] = 0;
            idx[dn]++;
          end
        end

      $fclose(wd);
      $fclose(bd);

      for (int n = 0; n < GOBOU_CORE; n++) begin
        for (int i = 0; i < 2**GOBOU_NETSIZE; i++) begin
          net_sel   = n;
          net_we    = 1;
          net_addr  = i;
          net_wdata = mem_n[n][i];
          #(STEP);
        end

        net_sel   = 0;
        net_we    = 0;
        net_addr  = 0;
        net_wdata = 0;
        #(STEP);
      end
    end // }}}
  endtask

  task read_params_direct;
    int idx[GOBOU_CORE-1:0];
    int wd, bd;
    int r;
    begin // {{{
      for (int dn = 0; dn < GOBOU_CORE; dn++)
        idx[dn] = 0;
      wd = $fopen("../../data/gobou/weight_gobou_top.dat", "r");
      bd = $fopen("../../data/gobou/bias_gobou_top.dat", "r");

      // reading iterations for normal weight sets
      for (int n = 0; n < N_OUT/GOBOU_CORE; n++)
        for (int dn = 0; dn < GOBOU_CORE; dn++) begin
          for (int m = 0; m < N_IN; m++) begin
            r = $fscanf(wd, "%x", mem_n[dn][idx[dn]]);
            idx[dn]++;
          end
          r = $fscanf(bd, "%x", mem_n[dn][idx[dn]]);
          idx[dn]++;
        end

      // reading iteration for a boundary weight set (if exists)
      if (N_OUT % GOBOU_CORE != 0)
        for (int dn = 0; dn < GOBOU_CORE; dn++) begin
          // put remainder weights to cores
          if ((GOBOU_CORE * (N_OUT/GOBOU_CORE) + dn) < N_OUT) begin
            for (int m = 0; m < N_IN; m++) begin
              r = $fscanf(wd, "%x", mem_n[dn][idx[dn]]);
              idx[dn]++;
            end
            r = $fscanf(bd, "%x", mem_n[dn][idx[dn]]);
            idx[dn]++;
          end
          // put null (zero) values to unused cores
          else begin
            for (int m = 0; m < N_IN; m++) begin
              mem_n[dn][idx[dn]] = 0;
              idx[dn]++;
            end
            mem_n[dn][idx[dn]] = 0;
            idx[dn]++;
          end
        end

      $fclose(wd);
      $fclose(bd);
    end // }}}
  endtask

  task write_output;
    int fd;
    int out_size;
    begin // {{{
      fd = $fopen("../../data/gobou/output_gobou_top.dat", "w");
      out_size = N_OUT;

      for (int i = 0; i < out_size; i++) begin
        img_addr = i + OUT_OFFSET;
        #(STEP*2);
        `ifdef NINJIN
        `else
        assert (mem_img.mem[img_addr] == mem_img_rdata);
        `endif
        $fdisplay(fd, "%0d", mem_img_rdata);
      end

      img_addr = 0;
      #(STEP);

      $fclose(fd);
    end // }}}
  endtask

  // display
  initial begin
    forever begin // {{{
      #(STEP/2-1);
      now_time = $time/STEP;
      if (now_time >= req_time)
        $display(
          "%5d: ", now_time - req_time,
          "%d ", req,
          "%d ", ack,
          "*%d ", dut.ctrl.ctrl_core.state$,
          "| ",
          "%d ", mem_img_we,
          "%d ", mem_img_addr,
          "%d ", mem_img_wdata,
          "%d ", mem_img_rdata,
          "| ",
          "%4d ",  dut.mem_net_we,
          "%4d ",  dut.mem_net_addr,
          "%4d ",  dut.net_wdata,
          "%4d ",  dut.net_rdata[0],
          "| ",
          "%1d ", dut.ctrl.ctrl_core.out_ctrl.valid,
          "%1d ", dut.ctrl.ctrl_mac.out_ctrl.valid,
          "%1d ", dut.ctrl.ctrl_bias.out_ctrl.valid,
          "%1d ", dut.ctrl.ctrl_relu.out_ctrl.valid,
          "| ",
          "%3d ",  dut.ctrl.ctrl_core.count_out$,
          "%3d ",  dut.ctrl.ctrl_core.count_in$,
          "| ",
          "%1b ",  dut.pe[0].core.mac.reset,
          "%1b ",  dut.pe[0].core.mac.out_en,
          "%1b ",  dut.pe[0].core.mac.accum_we,
          ": ",
          "%4d ",  dut.pe[0].core.mac.x,
          "%4d ",  dut.pe[0].core.mac.w,
          "%4d ",  dut.pe[0].core.mac.x$,
          "%4d ",  dut.pe[0].core.mac.w$,
          "%4d ",  dut.pe[0].core.mac.pro_short$,
          "%5d ",  dut.pe[0].core.mac.accum$,
          "%4d ",  dut.pe[0].core.mac.y$,
          "%4d ",  dut.pe[0].core.bias.pixel_out,
          "%4d ",  dut.pe[0].core.relu.pixel_out,
          ": ",
          "%4d ",  dut.pe[0].core.bias.bias$,
          "|"
        );
      #(STEP/2+1);
    end // }}}
  end

endmodule
