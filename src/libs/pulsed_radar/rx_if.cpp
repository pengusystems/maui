#include "rx_if.h"

void RX_IF::operator()(hls::stream< ap_int<ADC_WIDTH > > &rx_in) {
#pragma HLS PIPELINE
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis register both port=rx_in

	ap_int<ADC_WIDTH> adc_sample;
	rx_in.read(adc_sample);
#ifndef __SYNTHESIS__
	std::cout << "rx in sample = " << adc_sample << std::endl;
#endif
}



