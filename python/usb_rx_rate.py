#-*- coding:utf-8 -*-
# Python3

from time import time

from USB_FTX232H_FT60X import USB_FTX232H_FT60X_sync245mode




if __name__ == '__main__':
    
    usb = USB_FTX232H_FT60X_sync245mode(device_to_open_list =
        (('FTX232H', 'USB <-> Serial Converter'   ),           # firstly try to open FTX232H (FT232H or FT2232H) device named 'USB <-> Serial Converter'. Note that 'USB <-> Serial Converter' is the default name of FT232H or FT2232H chip unless the user has modified it. If the chip's name has been modified, you can use FT_Prog software to look up it.
         ('FT60X'  , 'FTDI SuperSpeed-FIFO Bridge'))           # secondly try to open FT60X (FT600 or FT601) device named 'FTDI SuperSpeed-FIFO Bridge'. Note that 'FTDI SuperSpeed-FIFO Bridge' is the default name of FT600 or FT601 chip unless the user has modified it.
    )
    
    print("\n  Reading...")
    
    rxlen_total = 0
    
    time_start = time()
    
    for ii in range(64):
        recv_data = usb.recv(1048576)
        rxlen_total += len(recv_data)
        print("    recv %dB ,  total %dB" % (len(recv_data), rxlen_total) )
    
    time_cost = time() - time_start
    
    print("\n  time:%.2fs   rate:%.2fMBps" % (time_cost, rxlen_total/(1+time_cost*1000000.0) ) )

    usb.close()
    