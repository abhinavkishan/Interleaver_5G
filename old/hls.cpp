#include "header.h"






#define MAX_E 32767

void interleaver(inDataStream &inData, outDataStream &outData, cnStream &cnData)
{
#pragma HLS INTERFACE axis port=inData
#pragma HLS INTERFACE axis port=outData
#pragma HLS INTERFACE axis port=cnData
#pragma HLS INTERFACE ap_ctrl_none port=return

    in_data_axi input;
    out_data_axi output;

    datau128b config = cnData.read();
    datau15b E  = config.range(14,0);
    datau4b  Qm = config.range(18,15);

    datau15b cols = E / Qm;

    // ---- four identical memories ----
    static ap_uint<16> in_bits0[2048];
    static ap_uint<16> in_bits1[2048];
    static ap_uint<16> in_bits2[2048];
    static ap_uint<16> in_bits3[2048];

    datau15b bit_count = 0;

    // ------------------------------------------------
    // INPUT STORAGE (same data copied into 4 memories)
    // ------------------------------------------------
    datau15b packets = (E + 95) / 96; 
    ap_uint<10> address=0;  // number of AXI packets

    INPUT:for(int p = 0; p < packets; p++)
    {
        input = inData.read();

        datau96b word = input.data;

        for(int i =6;i>0;i--) {
            in_bits0[address] = word.range(i*16-1,i*16-16);
            in_bits1[address] = word.range(i*16-1,i*16-16);
            in_bits2[address] = word.range(i*16-1,i*16-16);
            in_bits3[address] = word.range(i*16-1,i*16-16);

            address +=1;
    }

        
    }



    // ------------------------------------------------
    // INTERLEAVER OUTPUT
    // ------------------------------------------------

    datau96b out_word = 0;
    datau15b reference_pointers[8];
    datau15b pointers[8];
    ap_uint<11> pointers_word[8];
    datau4b  pointers_bit[8];
    ap_uint<7> index[8];

    datau4b left_over_bits=8;

    datau15b out_count =0;

    INITIALIZATION:for(int k=0;k<8;k++) {
                   reference_pointers[k] = cols*k;
                   index[k] =k;
    }


    OUTPUT:while(out_count <E) {
        ITERATION12:for(int i = 0; i < 12; i++)
        {
		#pragma HLS PIPELINE II=1
                POINTERCALC:for(int k=0;k<8;k++) {
				#pragma HLS UNROLL
                    if(Qm==8)  pointers[k] = reference_pointers[index[k]%8] + index[k]/8;
                    else if(Qm==6)  pointers[k] = reference_pointers[index[k]%6] + index[k]/6;
                    else if(Qm==4) pointers[k] = reference_pointers[index[k]%4] + index[k]/4;
                    else  pointers[k] = reference_pointers[index[k]%2] + index[k]/2;
                 

                    pointers_word[k] = pointers[k]/16;
                    pointers_bit[k] =  15-pointers[k]%16;
                    
    
                }

                // ---- 2 bits from each copy ----

               if(left_over_bits>=1) out_word[95-index[0]] = in_bits0[pointers_word[0]][pointers_bit[0]];
        
                if(left_over_bits>=2) out_word[95-index[1]] = in_bits0[pointers_word[1]][pointers_bit[1]];

                if(left_over_bits>=3) out_word[95-index[2]] = in_bits1[pointers_word[2]][pointers_bit[2]];
                
                if(left_over_bits>=4) out_word[95-index[3]] = in_bits1[pointers_word[3]][pointers_bit[3]];

                if(left_over_bits>=5) out_word[95-index[4]] = in_bits2[pointers_word[4]][pointers_bit[4]];

                if(left_over_bits>=6) out_word[95-index[5]] = in_bits2[pointers_word[5]][pointers_bit[5]];

                if(left_over_bits>=7) out_word[95-index[6]] = in_bits3[pointers_word[6]][pointers_bit[6]];

                if(left_over_bits==8) out_word[95-index[7]] = in_bits3[pointers_word[7]][pointers_bit[7]];
                out_count += left_over_bits;

                if(E - out_count>=8) left_over_bits =8;
                else left_over_bits = E-out_count;

                INDEX_UPDATE:for(int k=0;k<8;k++) {
#pragma HLS UNROLL
                index[k] =index[k] +8; 
            }   
            }

            REFRENCE_UPDATE:for(int k=0;k<8;k++) {
#pragma HLS UNROLL
                index[k] =k; 
                if (Qm==8)  reference_pointers[k] +=12;
            
                else if (Qm==6)    reference_pointers[k] +=16;
         
                else if (Qm==4) reference_pointers[k] +=24;
    
                else reference_pointers[k] +=48;
                
            }   


            output.data = out_word;
            output.last = (out_count>=E);
            outData.write(output);
            out_word = 0;
        }
        
        
           
    
}