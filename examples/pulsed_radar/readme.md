# Overview
This project is a WiP to demonstrate a basic transceiver for pulsed RADAR using HLS.\
Besides that, [This](./FIR_StaticCoeff.zip) is an example of FIR with stream interfaces found online.

## Running:
```
vivado_hls -f run_hls.tcl
vivado_hls -p proj_pulsed_radar
```

## Issues:
* In tx_if phase error accumulates, see the comment in tx_if.cpp

