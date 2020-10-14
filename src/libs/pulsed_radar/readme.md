#### workflow:
```
vivado_hls -f run_hls.tcl
vivado_hls -p proj_pulsed_radar
```
Issues:
* In tx_if phase error accumulates, see the comment in tx_if.cpp

Besides that, FIR_StaticCoeff.zip is an example of FIR with stream interfaces found online.