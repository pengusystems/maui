#include "ap_int.h"
#include "pulsed_radar.h"
#include <string>
#include <fstream>
#include <math.h>

int main() {
	const int num_samples = 1600;
	const double waveform_in_phase_inc_rad = (2*M_PI)/20;

	hls::stream<ap_int<DAC_WIDTH> > dac_out("DAC_OUT");
	hls::stream<ap_int<ADC_WIDTH> > adc_in("ADC_IN");
	double phase = 0;

	for (int ii = 0; ii < num_samples; ii++) {
		auto cosine = std::cos(phase);
		phase += waveform_in_phase_inc_rad;
		const double scale_factor = pow(2,ADC_WIDTH-1)-1; // need room for at least one 2's complement MSB.
		ap_int<ADC_WIDTH> cos_scaled = (ap_int<ADC_WIDTH>)(cosine * scale_factor);
		adc_in.write(cos_scaled);
		pulsed_radar_top(dac_out, adc_in);
		std::cout << "----- iter " << ii << " -----" << std::endl;
	}

	return 0;
}

