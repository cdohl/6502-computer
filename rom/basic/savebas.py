#! /usr/bin/python 
# Transport basic program to 6502 serial interface
import serial
import time
import sys

if (len(sys.argv) !=2):
    print("usage: savebas FILENAME")
    sys.exit()

st=0.003
stl=0.01
ser = serial.Serial('/dev/ttyUSB0', 9600, timeout=0.5)
with open(sys.argv[1], 'rb') as f:
    while 1:
        a=f.read(1)
        if not a:
            break
        if a==b'\n':
            ser.write(b'\r')
            time.sleep(stl)
        else: 
            ser.write(a)
            time.sleep(st)
        
        print(a.decode('ascii'),end='')
        

ser.close()
