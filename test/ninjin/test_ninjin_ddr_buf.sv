`include "ninjin.svh"

int READ_LEN   = 16;//16*12*12;
int WRITE_LEN  = 64;//32*4*4;

// int READ_OFFSET  = 42;
int READ_OFFSET  = 0;
int WRITE_OFFSET = 3000;

module test_ninjin_ddr_buf;

  parameter DDR_READ  = 'd0;
  parameter DDR_WRITE = 'd1;

  reg                     clk;
  reg                     xrst;
  reg [LWIDTH-1:0]        total_len;
  reg                     mem_we;
  reg [IMGSIZE-1:0]       mem_addr;
  reg signed [DWIDTH-1:0] mem_wdata;
  reg [BWIDTH-1:0]        ddr_rdata;
  wire                      ddr_we;
  wire                      ddr_re;
  wire [IMGSIZE-1:0]        ddr_addr;
  wire [BWIDTH-1:0]         ddr_wdata;
  wire signed [DWIDTH-1:0]  mem_rdata;

  ninjin_ddr_buf dut(.*);

  // clock
  initial begin
    clk = 0;
    forever
      #(STEP/2) clk = ~clk;
  end

  //flow
  initial begin
    xrst = 0;
    #(STEP);

    xrst      = 1;
    total_len = 0;
    mem_we    = 0;
    mem_addr  = 0;
    mem_wdata = 0;
    ddr_rdata = 0;
    #(STEP);

    /*
    $display("### prefetch");
    mem_addr = mem_addr + 1;
    #(STEP);
    mem_addr = mem_addr - 1;
    #(STEP);
    #(10*STEP);

    $display("### two feature map reading");
    mem_we = 0;
    mem_addr  = READ_OFFSET;
    for (int i = 0; i < READ_LEN; i++) begin
      mem_addr  = mem_addr + 1;
      mem_wdata = 0;
      #(STEP);
    end
    #(10*STEP);
    for (int i = 0; i < READ_LEN; i++) begin
      mem_addr  = mem_addr + 1;
      mem_wdata = 0;
      #(STEP);
    end
    mem_we    = 0;
    mem_addr  = 0;
    mem_wdata = 0;
    #(STEP);
    #(5*STEP);

    $display("### delta address test");
    mem_addr  = 32;
    #(5*STEP);
    mem_addr = mem_addr+1;
    #(STEP);
    mem_addr = mem_addr-1;
    #(5*STEP);
    */

    $display("### writing");
    mem_we = 1;
    for (int i = 0; i < WRITE_LEN; i++) begin
      mem_addr  = i + WRITE_OFFSET;
      mem_wdata = i+128;
      #(STEP);
    end
    mem_we    = 0;
    mem_addr  = 0;
    mem_wdata = 0;
    #(STEP);

    #(10*STEP);

    $finish();
  end

  //display
  initial begin
    forever begin
      #(STEP/2-1);
      $display(
        "%5d: ", $time/STEP,
        "%d ", xrst,
        "| ",
        "%d ", dut.txn_start,
        "%d ", dut.txn_stop,
        "@ ",
        "%d ", dut.mode,
        "%d ", dut.r_mode,
        "%d ", dut.addr_diff,
        "| ",
        "%d ", mem_we,
        "%d ", mem_addr,
        "%4x ", mem_wdata,
        "%4x ", mem_rdata,
        "| ",
        "%d ", ddr_we,
        "%d ", ddr_re,
        "%d ", dut.r_mem_addr[0],
        "%d ", ddr_addr,
        "%8x ", ddr_wdata,
        "%8x ", ddr_rdata,
        "| ",
        "%d ", dut.r_turn,
        ": ",
        "%d ", dut.buf_we[0],
        "%d ", dut.buf_addr[0],
        "%8x ", dut.buf_wdata,
        "%8x ", dut.buf_rdata[0],
        ": ",
        "%d ", dut.buf_we[1],
        "%d ", dut.buf_addr[1],
        "%8x ", dut.buf_wdata,
        "%8x ", dut.buf_rdata[1],
        "|"
      );
      #(STEP/2+1);
    end
  end

endmodule
