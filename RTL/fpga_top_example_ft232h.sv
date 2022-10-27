
//--------------------------------------------------------------------------------------------------------
// Module  : fpga_top_example_ft232h
// Type    : synthesizable, FPGA's top, IP's example design
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: an example of ftdi_245fifo
//           the pins of this module should connect to FT232H chip
//           TX channel (FPGA -> FT232H -> USB-cable -> Host-PC) : send increasing bytes
//           RX channel (Host-PC -> USB-cable -> FT232H -> FPGA) : recv bytes and check whether it is increasing
//--------------------------------------------------------------------------------------------------------

module fpga_top_example_ft232h (
    input  wire         clk,   // main clock, connect to on-board crystal oscillator
    output wire         led,   // used to show whether the recv data meets expectations
    
    // USB2.0 HS (FT232H chip)
    output wire         usb_resetn,  // to FT232H's pin34 (RESET#) , Comment out this line if this signal is not connected to FPGA.
    output wire         usb_pwrsav,  // to FT232H's pin31 (PWRSAV#), Comment out this line if this signal is not connected to FPGA.
    output wire         usb_siwu,    // to FT232H's pin28 (SIWU#)  , Comment out this line if this signal is not connected to FPGA.
    input  wire         usb_clk,     // to FT232H's pin29 (CLKOUT)
    input  wire         usb_rxf,     // to FT232H's pin21 (RXF#)
    input  wire         usb_txe,     // to FT232H's pin25 (TXE#)
    output wire         usb_oe,      // to FT232H's pin30 (OE#)
    output wire         usb_rd,      // to FT232H's pin26 (RD#)
    output wire         usb_wr,      // to FT232H's pin27 (WR#)
    inout        [ 7:0] usb_data     // to FT232H's pin20~13 (ADBUS7~ADBUS0)
);


assign usb_resetn = 1'b1;  // 1=normal operation , Comment out this line if this signal is not connected to FPGA.
assign usb_pwrsav = 1'b1;  // 1=normal operation , Comment out this line if this signal is not connected to FPGA.
assign usb_siwu   = 1'b1;  // 1=send immidiently , Comment out this line if this signal is not connected to FPGA.


// for power on reset
reg  [ 3:0] reset_shift = '0;
reg         rstn = '0;

// USB send data stream
reg         usbtx_valid = 1'b0;
wire        usbtx_ready;
reg  [ 5:0] usbtx_datah = '0;
wire [31:0] usbtx_data;

// USB received data stream
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
    .C_DEXP      ( 0           )  // FTDI USB chip data width, 0=8bit, 1=16bit, 2=32bit ... for FT232H is 0, for FT600 is 1, for FT601 is 2.
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
    .usb_be      (             )  // FT232H do not have BE signals
);



endmodule
