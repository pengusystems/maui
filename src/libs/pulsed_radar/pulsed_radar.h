#ifndef PULSED_RADER_H
#define PULSED_RADAR_H

#include "tx_if.h"
#include "rx_if.h"
#include <hls_stream.h>

void pulsed_radar_top(hls::stream< ap_int<DAC_WIDTH > > &tx_out, hls::stream< ap_int<ADC_WIDTH > > &rx_in);

#endif

