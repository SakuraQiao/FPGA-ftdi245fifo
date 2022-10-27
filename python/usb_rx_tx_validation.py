#-*- coding:utf-8 -*-
# Python3

from random import randint

from USB_FTX232H_FT60X import USB_FTX232H_FT60X_sync245mode



def build_increasing_bytes(start, length):
    '''
        build_increasing_bytes(int, int) -> bytes
        build a increasing bytes , for example:
        build_increasing_bytes(0xFD, 6) -> b'\xFD\xFE\xFF\x00\x01\x02'
    '''
    return bytes(list(map(lambda x:(x+start)%256, range(length))))




TOTAL_IDX = 999


if __name__ == '__main__':
    
    usb = USB_FTX232H_FT60X_sync245mode(device_to_open_list =
        (('FTX232H', 'USB <-> Serial Converter'   ),           # firstly try to open FTX232H (FT232H or FT2232H) device named 'USB <-> Serial Converter'. Note that 'USB <-> Serial Converter' is the default name of FT232H or FT2232H chip unless the user has modified it. If the chip's name has been modified, you can use FT_Prog software to look up it.
         ('FT60X'  , 'FTDI SuperSpeed-FIFO Bridge'))           # secondly try to open FT60X (FT600 or FT601) device named 'FTDI SuperSpeed-FIFO Bridge'. Note that 'FTDI SuperSpeed-FIFO Bridge' is the default name of FT600 or FT601 chip unless the user has modified it.
    )
    
    # USB 设备打开后默认的接收超时和发送超时都是 2000 ms
    #usb.set_recv_timeout(4000)                          # 可以在这里重设接收超时
    #usb.set_send_timeout(4000)                          # 可以在这里重设发送超时
    
    txnum = 0
    rxnum = -1
    
    for idx in range(TOTAL_IDX):
        print('[%4d/%4d]' % (idx+1, TOTAL_IDX), end='  ')
        
        bytelen = 4 * randint(1,65536)
        
        if randint(0,1) == 0:                                          # 有一半的概率进行发送
            
            txdata = build_increasing_bytes(txnum, bytelen)
            
            txlen = usb.send(txdata)
            
            print('send %4d B' % txlen)
            
            if txlen > 0:
                txnum = txdata[txlen-1] + 1
            
        else:                                                          # 有一半的概率进行接收
            
            rxdata = usb.recv(bytelen)
            
            if len(rxdata) < bytelen:
                print('recv %4d B, timeout ***' % len(rxdata))
                exit(-1)
                
            if rxnum == -1:
                rxnum = rxdata[0]
            
            rxdata_expect = build_increasing_bytes(rxnum, len(rxdata))
            
            if rxdata == rxdata_expect:
                print('recv %4d B, validation OK' % len(rxdata))
            else:
                print('recv %4d B, validation failed: not in order! ***' % len(rxdata))
                exit(-1)
            
            rxnum = rxdata[-1] + 1

    usb.close()
    