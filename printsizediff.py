#!/usr/bin/env python3
import sys

argv=sys.argv[1:]

iec=["Byte","KiB","MiB","GiB","TiB","PiB","EiB","ZiB","YiB"]
si=["Byte","kB","MB","GB","TB","PB","EB","ZB","YB"]

if argv[0]=="-iec":
    vals=iec
    div=1024
    del argv[0]
elif argv[0]=="-si":
    vals=si
    div=1000
    del argv[0]
else:
    vals=iec
    div=1024

if len(argv)==3:
    label=argv[0]
    old=float(argv[1])
    new=float(argv[2])
    dif=new-old
    newsuf=0
    difsuf=0
    while abs(new)>=div and newsuf<len(vals)-1:
        newsuf+=1
        new/=div
    while abs(dif)>=div and difsuf<len(vals)-1:
        difsuf+=1
        dif/=div
    print("{:<12}\t{: > 9.2f} {:<4}\t\t{: =+9.2f} {:<4}".format(label,new,vals[newsuf],dif,vals[difsuf]))
