#ifndef RX_IF_H
#define RX_IF_H

#include "ap_int.h"
#include <hls_stream.h>

const int ADC_WIDTH = 16;

class RX_IF {
public:
	RX_IF() {};
	void operator()(hls::stream< ap_int<ADC_WIDTH > > &adc_in);
private:
};


#endif

