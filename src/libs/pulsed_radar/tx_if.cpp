#include "tx_if.h"
#include "hls_dsp.h"

// Define template parameters
const int ACCUM_WIDTH = 32;
const int PHASE_ANGLE_WIDTH = 16;
const int SUPER_SAMPLE_RATE = 1;
const int OUTPUT_WIDTH = 16;

// Define implementation of complex multiplier structures within the NCO
typedef hls::NcoDualOutputCmpyFiveMult DUAL_OUTPUT_CMPY_IMPL;
typedef hls::NcoSingleOutputCmpyThreeMult SINGLE_OUTPUT_CMPY_IMPL;
typedef hls::NcoSingleOutputCmpyThreeMult SINGLE_OUTPUT_NEG_CMPY_IMPL;

// Phase increment determines the output frequency.
const double if_freq_requested = 10e6;
const double clk_freq = 119.75e6;
const ap_uint<ACCUM_WIDTH> PINC = (unsigned int)(if_freq_requested * pow(2, ACCUM_WIDTH) / clk_freq);
const double if_freq_calculated = (clk_freq * (double)PINC) / pow(2, ACCUM_WIDTH);

// Modulation Code constants.
const ap_uint<ACCUM_WIDTH> BPSK_OFFSET_0 = 0;
const ap_uint<ACCUM_WIDTH> BPSK_OFFSET_180 = (unsigned int)(pow(2,ACCUM_WIDTH)/2 - 1);
const int SAMPLES_PER_CHIP = 90;
const int code[] = {1, 1, 1, -1};
const int code_size = 4;

TX_IF::TX_IF() {
	sample_index = 0;
	chip_index = 0;
}

void TX_IF::operator()(hls::stream< ap_int<DAC_WIDTH > > &tx_out) {
#pragma HLS PIPELINE
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis register both port=dac_out

	static hls::nco<ACCUM_WIDTH, PHASE_ANGLE_WIDTH, SUPER_SAMPLE_RATE, OUTPUT_WIDTH, DUAL_OUTPUT_CMPY_IMPL, SINGLE_OUTPUT_CMPY_IMPL, SINGLE_OUTPUT_NEG_CMPY_IMPL> nco(PINC, 0);
	static hls::stream<ap_uint<ACCUM_WIDTH> > pinc("PINC");
	static hls::stream<ap_uint<ACCUM_WIDTH> > poff("POFF");
	static hls::stream< hls::t_nco_output_data<SUPER_SAMPLE_RATE, OUTPUT_WIDTH> > out("NCO output data");

	// BPSK modulation waveform.
//	sample_index++;
//	if ((sample_index % SAMPLES_PER_CHIP) == 0) {
//		chip_index++;
//		if (chip_index == code_size) {
//			chip_index = 0;
//		}
//	}
	sample_index = (sample_index + 1) % (SAMPLES_PER_CHIP * code_size);

	// Apply BPSK modulation using the phase offset.
	pinc.write(PINC);
	unsigned int code_index = sample_index / SAMPLES_PER_CHIP;
	(code[code_index] == 1) ? poff.write(BPSK_OFFSET_0) : poff.write(BPSK_OFFSET_180);

	// Execute a cycle of the NCO.
	nco(pinc, poff, out);
	hls::t_nco_output_data<SUPER_SAMPLE_RATE, OUTPUT_WIDTH> out_sample;
	out.read(out_sample);
	ap_int<OUTPUT_WIDTH> q_sample, i_sample;
	i_sample = out_sample.outputValue[0].real();
	q_sample = out_sample.outputValue[0].imag();
	ap_int<DAC_WIDTH>add_sample = i_sample;
	//ap_int<DAC_WIDTH>add_sample = i_sample + q_sample;
	tx_out.write(add_sample);

	// Report.
	// Here there is an issue with the phase not being periodic at the end of each cycle such that each cycle
	// the accumulator will not go back to 0. This happens since 2^ACCUM_WIDTH / PINC is not an integer.
	// See phase dithered DDS in Xilinx DDS Compiler v6.0 PG141.
#ifndef __SYNTHESIS__
	double measured_phase = atan2((double)q_sample,(double)i_sample) * 180/3.14159;
	if (measured_phase < 0) {
		measured_phase += 360;
	}
	std::cout << "tx out sample = " << add_sample << ", phase = " << measured_phase << std::endl;
#endif
}



