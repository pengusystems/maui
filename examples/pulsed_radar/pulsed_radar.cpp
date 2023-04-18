#include "pulsed_radar.h"

void pulsed_radar_top(hls::stream< ap_int<DAC_WIDTH > > &tx_out, hls::stream< ap_int<ADC_WIDTH > > &rx_in) {
#pragma HLS DATAFLOW
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis register both port=rx_in
#pragma HLS INTERFACE axis register both port=tx_out
	static TX_IF tx_if;
	static RX_IF rx_if;

	// Use operator () to operate on a per-sample basis.
	// tx_if will write a sample to the dac_out stream.
	// rx_if will read a sample from the adc_in stream.
	rx_if(rx_in);
	tx_if(tx_out);
}



