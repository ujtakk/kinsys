`include "ninjin.svh"

module ninjin
 #(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH  = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH  = 7
  )
  (
    // Users to add ports here

    output [C_S_AXI_DATA_WIDTH-1:0] port[PORT/2-1:0],
    input  [C_S_AXI_DATA_WIDTH-1:0] port[PORT-1:PORT/2],

    // User ports ends
    // Do not modify the ports beyond this line

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
        // privilege and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
        // valid write address and control information.
    input wire  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
        // to accept an address and associated control signals.
    output wire  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
        // data and strobes are available.
    input wire  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
        // can accept the write data.
    output wire  S_AXI_WREADY,
    // Write response. This signal indicates the status
        // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
        // is signaling a valid write response.
    output wire  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
        // can accept a write response.
    input wire  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether the
        // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
        // is signaling valid read address and control information.
    input wire  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
        // ready to accept an address and associated control signals.
    output wire  S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
        // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
        // signaling the required read data.
    output wire  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
        // accept the read data and response information.
    input wire  S_AXI_RREADY
  );

  // AXI4LITE signals
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
  reg   axi_awready;
  reg   axi_wready;
  reg [1 : 0]   axi_bresp;
  reg   axi_bvalid;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
  reg   axi_arready;
  reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
  reg [1 : 0]   axi_rresp;
  reg   axi_rvalid;

  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2)
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 4;
  //----------------------------------------------
  //-- Signals for user logic register space example
  //------------------------------------------------
  //-- Number of Slave Registers PORT
  reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg [PORT-1:0];
  wire   slv_reg_rden;
  wire   slv_reg_wren;
  reg [C_S_AXI_DATA_WIDTH-1:0]   reg_data_out;
  integer  byte_index;

  // I/O Connections assignments

  assign S_AXI_AWREADY  = axi_awready;
  assign S_AXI_WREADY = axi_wready;
  assign S_AXI_BRESP  = axi_bresp;
  assign S_AXI_BVALID = axi_bvalid;
  assign S_AXI_ARREADY  = axi_arready;
  assign S_AXI_RDATA  = axi_rdata;
  assign S_AXI_RRESP  = axi_rresp;
  assign S_AXI_RVALID = axi_rvalid;
  // Implement axi_awready generation
  // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
  // de-asserted when reset is low.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_awready <= 1'b0;
      end
    else
      begin
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
          begin
            // slave is ready to accept write address when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            axi_awready <= 1'b1;
          end
        else
          begin
            axi_awready <= 1'b0;
          end
      end
  end

  // Implement axi_awaddr latching
  // This process is used to latch the address when both
  // S_AXI_AWVALID and S_AXI_WVALID are valid.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_awaddr <= 0;
      end
    else
      begin
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
          begin
            // Write Address latching
            axi_awaddr <= S_AXI_AWADDR;
          end
      end
  end

  // Implement axi_wready generation
  // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
  // de-asserted when reset is low.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_wready <= 1'b0;
      end
    else
      begin
        if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
          begin
            // slave is ready to accept write data when
            // there is a valid write address and write data
            // on the write address and data bus. This design
            // expects no outstanding transactions.
            axi_wready <= 1'b1;
          end
        else
          begin
            axi_wready <= 1'b0;
          end
      end
  end

  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

  // TODO: write generate version of the following always
  // for (genvar i = 0; i < PORT; i++)
  //   always @( posedge S_AXI_ACLK )
  //     if ( S_AXI_ARESETN == 1'b0 )
  //       slv_reg[i] <= 0;
  //     else begin
  //       if (slv_reg_wren)

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        slv_reg[0] <= 0;
        slv_reg[1] <= 0;
        slv_reg[2] <= 0;
        slv_reg[3] <= 0;
        slv_reg[4] <= 0;
        slv_reg[5] <= 0;
        slv_reg[6] <= 0;
        slv_reg[7] <= 0;
        slv_reg[8] <= 0;
        slv_reg[9] <= 0;
        slv_reg[10] <= 0;
        slv_reg[11] <= 0;
        slv_reg[12] <= 0;
        slv_reg[13] <= 0;
        slv_reg[14] <= 0;
        slv_reg[15] <= 0;
        slv_reg[16] <= 0;
        slv_reg[17] <= 0;
        slv_reg[18] <= 0;
        slv_reg[19] <= 0;
        slv_reg[20] <= 0;
        slv_reg[21] <= 0;
        slv_reg[22] <= 0;
        slv_reg[23] <= 0;
        slv_reg[24] <= 0;
        slv_reg[25] <= 0;
        slv_reg[26] <= 0;
        slv_reg[27] <= 0;
        slv_reg[28] <= 0;
        slv_reg[29] <= 0;
        slv_reg[30] <= 0;
        slv_reg[31] <= 0;
      end
    else begin
      if (slv_reg_wren)
        begin
          case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            5'h00:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 0
                  slv_reg[0][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h01:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 1
                  slv_reg[1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h02:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 2
                  slv_reg[2][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h03:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 3
                  slv_reg[3][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h04:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 4
                  slv_reg[4][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h05:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 5
                  slv_reg[5][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h06:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 6
                  slv_reg[6][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h07:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 7
                  slv_reg[7][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h08:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 8
                  slv_reg[8][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h09:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 9
                  slv_reg[9][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0A:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 10
                  slv_reg[10][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0B:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 11
                  slv_reg[11][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0C:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 12
                  slv_reg[12][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0D:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 13
                  slv_reg[13][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0E:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 14
                  slv_reg[14][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h0F:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 15
                  slv_reg[15][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h10:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 16
                  slv_reg[16][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h11:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 17
                  slv_reg[17][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h12:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 18
                  slv_reg[18][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h13:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 19
                  slv_reg[19][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h14:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 20
                  slv_reg[20][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h15:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 21
                  slv_reg[21][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h16:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 22
                  slv_reg[22][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h17:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 23
                  slv_reg[23][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h18:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 24
                  slv_reg[24][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h19:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 25
                  slv_reg[25][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1A:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 26
                  slv_reg[26][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1B:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 27
                  slv_reg[27][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1C:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 28
                  slv_reg[28][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1D:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 29
                  slv_reg[29][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1E:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 30
                  slv_reg[30][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            5'h1F:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                  // Respective byte enables are asserted as per write strobes
                  // Slave register 31
                  slv_reg[31][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            default : begin
                        slv_reg[0] <= slv_reg[0];
                        slv_reg[1] <= slv_reg[1];
                        slv_reg[2] <= slv_reg[2];
                        slv_reg[3] <= slv_reg[3];
                        slv_reg[4] <= slv_reg[4];
                        slv_reg[5] <= slv_reg[5];
                        slv_reg[6] <= slv_reg[6];
                        slv_reg[7] <= slv_reg[7];
                        slv_reg[8] <= slv_reg[8];
                        slv_reg[9] <= slv_reg[9];
                        slv_reg[10] <= slv_reg[10];
                        slv_reg[11] <= slv_reg[11];
                        slv_reg[12] <= slv_reg[12];
                        slv_reg[13] <= slv_reg[13];
                        slv_reg[14] <= slv_reg[14];
                        slv_reg[15] <= slv_reg[15];
                        slv_reg[16] <= slv_reg[16];
                        slv_reg[17] <= slv_reg[17];
                        slv_reg[18] <= slv_reg[18];
                        slv_reg[19] <= slv_reg[19];
                        slv_reg[20] <= slv_reg[20];
                        slv_reg[21] <= slv_reg[21];
                        slv_reg[22] <= slv_reg[22];
                        slv_reg[23] <= slv_reg[23];
                        slv_reg[24] <= slv_reg[24];
                        slv_reg[25] <= slv_reg[25];
                        slv_reg[26] <= slv_reg[26];
                        slv_reg[27] <= slv_reg[27];
                        slv_reg[28] <= slv_reg[28];
                        slv_reg[29] <= slv_reg[29];
                        slv_reg[30] <= slv_reg[30];
                        slv_reg[31] <= slv_reg[31];
                      end
          endcase
        end
      else
      begin
        slv_reg[16] <= port[16];
        slv_reg[17] <= port[17];
        slv_reg[18] <= port[18];
        slv_reg[19] <= port[19];
        slv_reg[20] <= port[20];
        slv_reg[21] <= port[21];
        slv_reg[22] <= port[22];
        slv_reg[23] <= port[23];
        slv_reg[24] <= port[24];
        slv_reg[25] <= port[25];
        slv_reg[26] <= port[26];
        slv_reg[27] <= port[27];
        slv_reg[28] <= port[28];
        slv_reg[29] <= port[29];
        slv_reg[30] <= port[30];
        slv_reg[31] <= port[31];
      end
    end
  end

  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave
  // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
  // This marks the acceptance of address and indicates the status of
  // write transaction.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_bvalid  <= 0;
        axi_bresp   <= 2'b0;
      end
    else
      begin
        if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
          begin
            // indicates a valid write response is available
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; // 'OKAY' response
          end                   // work error responses in future
        else
          begin
            if (S_AXI_BREADY && axi_bvalid)
              //check if bready is asserted while bvalid is high)
              //(there is a possibility that bready is always asserted high)
              begin
                axi_bvalid <= 1'b0;
              end
          end
      end
  end

  // Implement axi_arready generation
  // axi_arready is asserted for one S_AXI_ACLK clock cycle when
  // S_AXI_ARVALID is asserted. axi_awready is
  // de-asserted when reset (active low) is asserted.
  // The read address is also latched when S_AXI_ARVALID is
  // asserted. axi_araddr is reset to zero on reset assertion.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_arready <= 1'b0;
        axi_araddr  <= 32'b0;
      end
    else
      begin
        if (~axi_arready && S_AXI_ARVALID)
          begin
            // indicates that the slave has acceped the valid read address
            axi_arready <= 1'b1;
            // Read address latching
            axi_araddr  <= S_AXI_ARADDR;
          end
        else
          begin
            axi_arready <= 1'b0;
          end
      end
  end

  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_ARVALID and axi_arready are asserted. The slave registers
  // data are available on the axi_rdata bus at this instance. The
  // assertion of axi_rvalid marks the validity of read data on the
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid
  // is deasserted on reset (active low). axi_rresp and axi_rdata are
  // cleared to zero on reset (active low).
  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_rvalid <= 0;
        axi_rresp  <= 0;
      end
    else
      begin
        if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
          begin
            // Valid read data is available at the read data bus
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b0; // 'OKAY' response
          end
        else if (axi_rvalid && S_AXI_RREADY)
          begin
            // Read data is accepted by the master
            axi_rvalid <= 1'b0;
          end
      end
  end

  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  always @(*)
  begin
        // Address decoding for reading registers
        case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
          5'h00   : reg_data_out <= slv_reg[0];
          5'h01   : reg_data_out <= slv_reg[1];
          5'h02   : reg_data_out <= slv_reg[2];
          5'h03   : reg_data_out <= slv_reg[3];
          5'h04   : reg_data_out <= slv_reg[4];
          5'h05   : reg_data_out <= slv_reg[5];
          5'h06   : reg_data_out <= slv_reg[6];
          5'h07   : reg_data_out <= slv_reg[7];
          5'h08   : reg_data_out <= slv_reg[8];
          5'h09   : reg_data_out <= slv_reg[9];
          5'h0A   : reg_data_out <= slv_reg[10];
          5'h0B   : reg_data_out <= slv_reg[11];
          5'h0C   : reg_data_out <= slv_reg[12];
          5'h0D   : reg_data_out <= slv_reg[13];
          5'h0E   : reg_data_out <= slv_reg[14];
          5'h0F   : reg_data_out <= slv_reg[15];
          5'h10   : reg_data_out <= slv_reg[16];
          5'h11   : reg_data_out <= slv_reg[17];
          5'h12   : reg_data_out <= slv_reg[18];
          5'h13   : reg_data_out <= slv_reg[19];
          5'h14   : reg_data_out <= slv_reg[20];
          5'h15   : reg_data_out <= slv_reg[21];
          5'h16   : reg_data_out <= slv_reg[22];
          5'h17   : reg_data_out <= slv_reg[23];
          5'h18   : reg_data_out <= slv_reg[24];
          5'h19   : reg_data_out <= slv_reg[25];
          5'h1A   : reg_data_out <= slv_reg[26];
          5'h1B   : reg_data_out <= slv_reg[27];
          5'h1C   : reg_data_out <= slv_reg[28];
          5'h1D   : reg_data_out <= slv_reg[29];
          5'h1E   : reg_data_out <= slv_reg[30];
          5'h1F   : reg_data_out <= slv_reg[31];
          default : reg_data_out <= 0;
        endcase
  end

  // Output register or memory read data
  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
      begin
        axi_rdata  <= 0;
      end
    else
      begin
        // When there is a valid read address (S_AXI_ARVALID) with
        // acceptance of read address by the slave (axi_arready),
        // output the read dada
        if (slv_reg_rden)
          begin
            axi_rdata <= reg_data_out;     // register read data
          end
      end
  end

  // Add user logic here

  for (genvar i = 0; i < PORT/2; i++)
    assign port[i] = slv_reg[i][C_S_AXI_DATA_WIDTH-1:0];

  // User logic ends

endmodule