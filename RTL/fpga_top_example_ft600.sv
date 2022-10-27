
//--------------------------------------------------------------------------------------------------------
// Module  : fpga_top_example_ft600
// Type    : synthesizable, FPGA's top, IP's example design
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: an example of ftdi_245fifo
//           the pins of this module should connect to FT600 chip
//           TX channel (FPGA -> FT600 -> USB-cable -> Host-PC) : send increasing bytes
//           RX channel (Host-PC -> USB-cable -> FT600 -> FPGA) : recv bytes and check whether it is increasing
//--------------------------------------------------------------------------------------------------------

module fpga_top_example_ft600 (
    input  wire         clk,   // main clock, connect to on-board crystal oscillator
    output wire         led,   // used to show whether the recv data meets expectations
    
    // USB3.0 (FT600 chip)
    output wire         usb_resetn,    // to FT600's pin10 (RESET_N) , Comment out this line if this signal is not connected to FPGA.
    output wire         usb_wakeupn,   // to FT600's pin11 (WAKEUP_N), Comment out this line if this signal is not connected to FPGA.
    output wire         usb_gpio0,     // to FT600's pin12 (GPIO0)   , Comment out this line if this signal is not connected to FPGA.
    output wire         usb_gpio1,     // to FT600's pin13 (GPIO1)   , Comment out this line if this signal is not connected to FPGA.
    output wire         usb_siwu,      // to FT600's pin6  (SIWU_N)  , Comment out this line if this signal is not connected to FPGA.
    input  wire         usb_clk,       // to FT600's pin43 (CLK)
    input  wire         usb_rxf,       // to FT600's pin5  (RXF_N)
    input  wire         usb_txe,       // to FT600's pin4  (TXE_N)
    output wire         usb_oe,        // to FT600's pin9  (OE_N)
    output wire         usb_rd,        // to FT600's pin8  (RD_N)
    output wire         usb_wr,        // to FT600's pin7  (WR_N)
    output wire  [ 1:0] usb_be,        // to FT600's pin3 (BE_1) and pin2 (BE_0)
    inout        [15:0] usb_data       // to FT600's pin56~53 (DATA_15~DATA_12) , pin48~45 (DATA_11~DATA_8) , pin42~39 (DATA_7~DATA4) and pin36~33 (DATA_3~DATA_0)
);


assign usb_resetn = 1'b1;  // 1=normal operation , Comment out this line if this signal is not connected to FPGA.
assign usb_wakeupn= 1'b0;  // 0=wake up          , Comment out this line if this signal is not connected to FPGA.
assign usb_gpio0  = 1'b0;  // GPIO[1:0]=00 = 245fifo mode , Comment out this line if this signal is not connected to FPGA.
assign usb_gpio1  = 1'b0;  //                             , Comment out this line if this signal is not connected to FPGA.
assign usb_siwu   = 1'b1;  // 1=send immidiently , Comment out this line if this signal is not connected to FPGA.


// for power on reset
reg  [ 3:0] reset_shift = '0;
reg         rstn = '0;

// USB send data stream
reg         usbtx_valid = 1'b0;
wire        usbtx_ready;
reg  [ 5:0] usbtx_datah = '0;
wire [31:0] usbtx_data;

// USB recieved data stream
wire        usbrx_valid;
reg         usbrx_ready = 1'b0;
wire [ 7:0] usbrx_data;

// other signals for USB received control
reg  [ 7:0] last_data = '0;
reg  [31:0] busy_cnt = 0;
reg  [15:0] error_cnt = '0;


assign led = error_cnt == '0;



//------------------------------------------------------------------------------------------------------------
// power on reset
//------------------------------------------------------------------------------------------------------------
always @ (posedge clk)
    {rstn, reset_shift} <= {reset_shift, 1'b1};



//------------------------------------------------------------------------------------------------------------
// USB TX behavior : always try to send increasing bytes
//------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        usbtx_valid <= 1'b0;
        usbtx_datah <= '0;
    end else begin
        if(usbtx_valid & usbtx_ready)                           // if send success,
            usbtx_datah <= usbtx_datah + 6'd1;                  // send increasing bytes
        usbtx_valid <= 1'b1;                                    // always try to send
    end

assign usbtx_data = { usbtx_datah, 2'd3,
                      usbtx_datah, 2'd2,
                      usbtx_datah, 2'd1,
                      usbtx_datah, 2'd0  };                     // send increasing bytes



//------------------------------------------------------------------------------------------------------------
// USB RX behavior : check
//------------------------------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        last_data <= '0;
        busy_cnt <= 0;
        error_cnt <= '0;
        usbrx_ready <= 1'b0;
    end else begin
        if(usbrx_valid & usbrx_ready) begin                    // recv a data
            if(busy_cnt != 0)                                  // busy_cnt>0 means there is a received data in the past 0.1 seconds
                if(usbrx_data != last_data + 8'd1)             // mismatch: RX data not increasing
                    error_cnt <= '1;                           // detected that RX data not increasing !!!
                else if(error_cnt != '0)                       // match : RX data is increasing
                    error_cnt <= error_cnt - 16'd1;            // 
            last_data <= usbrx_data;                           // save the last RX data
            busy_cnt <= 5000000;                               //
        end else if(busy_cnt != 0) begin
            busy_cnt <= busy_cnt - 1;
        end
        usbrx_ready <= 1'b1;                                   // recv always ready
    end



//------------------------------------------------------------------------------------------------------------
// USB TX and RX controller
//------------------------------------------------------------------------------------------------------------
ftdi_245fifo #(
    .TX_DEXP     ( 2           ), // TX data stream width,  0=8bit, 1=16bit, 2=32bit, 3=64bit, 4=128bit ...
    .TX_AEXP     ( 10          ), // TX FIFO depth = 2^TX_AEXP = 2^10 = 1024
    .RX_DEXP     ( 0           ), // RX data stream width,  0=8bit, 1=16bit, 2=32bit, 3=64bit, 4=128bit ...
    .RX_AEXP     ( 10          ), // RX FIFO depth = 2^RX_AEXP = 2^10 = 1024
    .C_DEXP      ( 1           )  // FTDI USB chip data width, 0=8bit, 1=16bit, 2=32bit ... for FT232H is 0, for FT600 is 1, for FT601 is 2.
) ftdi_245fifo_i (
    .rstn_async  ( rstn        ),
    .tx_clk      ( clk         ),
    .tx_valid    ( usbtx_valid ),
    .tx_ready    ( usbtx_ready ),
    .tx_data     ( usbtx_data  ),
    .rx_clk      ( clk         ),
    .rx_valid    ( usbrx_valid ), 
    .rx_ready    ( usbrx_ready ),
    .rx_data     ( usbrx_data  ),
    .usb_clk     ( usb_clk     ),
    .usb_rxf     ( usb_rxf     ),
    .usb_txe     ( usb_txe     ),
    .usb_oe      ( usb_oe      ),
    .usb_rd      ( usb_rd      ),
    .usb_wr      ( usb_wr      ),
    .usb_data    ( usb_data    ),
    .usb_be      ( usb_be      )
);



endmodule
