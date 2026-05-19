#include "ap_int.h"
#include "hls_stream.h"
#include "hls_math.h"
#include "ap_axi_sdata.h"

typedef ap_uint<128> datau128b;
typedef ap_uint<22>  datau22b;
typedef ap_uint<21>  datau21b;
typedef ap_uint<20>  datau20b;
typedef ap_uint<19>  datau19b;
typedef ap_uint<15>  datau15b;
typedef ap_uint<16>  datau16b;
typedef ap_uint<14>  datau14b;
typedef ap_uint<10>  datau10b;
typedef ap_uint<9>   datau9b;
typedef ap_uint<6>   datau6b;
typedef ap_uint<4>   datau4b;
typedef ap_uint<3>   datau3b;
typedef ap_uint<2>   datau2b;
typedef ap_uint<1>   datau1b;
typedef ap_uint<7>   datau7b;


typedef  hls::axis<ap_uint<128>,0,0,0,AXIS_DISABLE_ALL>  config_type;
typedef  hls::axis<ap_uint<67>,0,0,0,AXIS_DISABLE_ALL>  out_type;
typedef hls::stream<config_type> config_stream_type;
typedef hls::stream<out_type> out_stream_type;

void KEC(
    config_stream_type &config_stream,
    out_stream_type &out_stream
) 
{

    #pragma HLS INTERFACE axis port=config_stream
    #pragma HLS INTERFACE axis port=out_stream
    #pragma HLS INTERFACE ap_ctrl_none port=return



            datau16b E;
            datau16b Ko;
            config_type config_in = config_stream.read();
            ap_uint<128> cnData_tdata = config_in.data;
            datau6b  C     = cnData_tdata.range(29, 24);
            datau6b  Cr     = cnData_tdata.range(122, 117);
            datau19b TBS   = cnData_tdata.range(18,  0);
            datau1b  Bg_No = cnData_tdata.range(19, 19);
            datau9b  Z_c   = cnData_tdata.range(70, 62);
            datau4b  Qm    = cnData_tdata.range(23, 20);
            datau3b  V     = cnData_tdata.range(34, 32);
            datau14b K_    = cnData_tdata.range(87, 74);
            datau19b G     = cnData_tdata.range(106, 88);
            datau2b  RV    = cnData_tdata.range(31, 30);

            // -------- Compute N, K --------
            datau15b N;
            datau14b K;
            if (Bg_No == 0) {
                N = 66 * Z_c;
                K = 22 * Z_c;
            } else {
                N = 50 * Z_c;
                K = 10 * Z_c;
            }

            // -------- Nref, Ncb --------
            datau15b Nref = hls::divide((datau20b)(TBS*3), (datau20b)(2*C));
            datau15b Ncb  = (N < Nref) ? N : Nref;

            // -------- st1 & Etemp --------
            datau4b  st1   = V * Qm;
            ap_uint<14> BPR;
            
            //datau22b Etemp = (datau22b)(hls::divide(G,(st1*C)));
            BPR= hls::divide(G,(datau19b)(st1*C));
            BPR = BPR*V;
            E = BPR*Qm;
            datau10b F = K - K_;

            // -------- k0 --------
            datau15b k0;

            if (Bg_No == 0) {
                if (RV == 0) k0 = 0;
                else if (RV == 1) k0 = hls::divide((datau21b)(17 * Ncb), (datau21b)(N)) * Z_c;
                else if (RV == 2) k0 =  hls::divide((datau21b)(33 * Ncb), (datau21b)(N)) * Z_c;
                else k0 = hls::divide((datau21b)(56 * Ncb), (datau21b)(N)) * Z_c;
            } else {
                if (RV == 0) k0 = 0;
                else if (RV == 1) k0 = hls::divide((datau21b)(13 * Ncb), (datau21b)(N)) * Z_c;
                else if (RV == 2) k0 = hls::divide((datau21b)(25 * Ncb), (datau21b)(N)) * Z_c;
                else k0 = hls::divide((datau21b)(43 * Ncb), (datau21b)(N)) * Z_c;
            }

            datau14b K1 = K - 2 * Z_c;
	        datau14b K2 = K_ - 2 * Z_c;

            if (k0 > K1)
            {
                k0 = k0 - F;
            }
            else if ((k0 > K2) && (k0 <= K1) && (Ncb > K2) && (Ncb <= K1))
            {
                k0 = 0;
            }
            else if ((k0 > K2) && (k0 <= K1))
            {
                k0 = K2;
            }

            // -------- Store outputs --------
            Ko = k0;
            out_type out;
            
            out.data.range(66,52) = BPR;
            out.data.range(51,36) =E;
            out.data.range(35,20) = Ko;
            out.data.range(19,14) =C;
            out.data.range(13,8) = Cr;
            out.data.range(7,4) =Qm;
            out.data.range(3,0) =V;
    
            out_stream.write(out);
}