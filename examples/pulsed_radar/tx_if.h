#ifndef TX_IF_H
#define TX_IF_H

#include "ap_int.h"
#include <hls_stream.h>

const int DAC_WIDTH = 16;

class TX_IF {
public:
	TX_IF();
	void operator()(hls::stream< ap_int<DAC_WIDTH > > &dac_out);
private:
	unsigned int sample_index;
	unsigned int chip_index;
};

#endif

