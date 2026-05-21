#include <hls_stream.h>
#include "ap_axi_sdata.h"
#include <ap_int.h>

using namespace hls;

typedef axis<ap_uint<128>,0,0,0,AXIS_ENABLE_KEEP | AXIS_ENABLE_LAST> data_axi_type;
typedef stream<data_axi_type> dataStream_type;

typedef axis<ap_uint<128>,0,0,0,AXIS_DISABLE_ALL> config_axi_type;
typedef stream<config_axi_type> configStream_type;

void sbi_config_input(configStream_type &configStream, dataStream_type &dataStream) {
    // Map function arguments to standard AXI4-Stream interfaces
    #pragma HLS interface mode=axis port=configStream register_mode=both
    #pragma HLS interface mode=axis port=dataStream   register_mode=both
    
    // Allows the block to run continuously in hardware (free-running loop)
    #pragma HLS interface mode=ap_ctrl_none port=return

    // Hardcoded 128-bit values initialized using base-16 strings
    const ap_uint<128> config_val = ap_uint<128>("00408841A046A334000F008902402308", 16);
    
    const ap_uint<128> data_vals[4] = {
        ap_uint<128>("4AC0AB35BE3A20FF7A7D7FCAD005A332", 16),
        ap_uint<128>("1BBF085C2BC611AE8820839D27ECB2E3", 16),
        ap_uint<128>("A5EE3894885B5289307400E398546B83", 16),
        ap_uint<128>("039E89EED41DC9E5F9AC17512AF70D6B", 16)
    };

    // 1. Supply the Configuration Word
    config_axi_type config_word;
    config_word.data = config_val;
    configStream.write(config_word);

    // 2. Supply the 4 Data Words in a pipelined loop
    for (int i = 0; i < 4; i++) {
        #pragma HLS pipeline II=1
        
        data_axi_type data_word;
        data_word.data = data_vals[i];
        
        if (i == 3) {
            // 4th word: assert TLAST and set TKEEP to 120
            data_word.last = 1;
            data_word.keep = 120; // 120 decimal (0x78 or 7'b1111000)
        } else {
            // First 3 words: no TLAST and set TKEEP to 127
            data_word.last = 0;
            data_word.keep = 127; // 127 decimal (0x7F or 7'b1111111)
        }

        dataStream.write(data_word);
    }
}