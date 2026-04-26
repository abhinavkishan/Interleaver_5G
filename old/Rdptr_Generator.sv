
module Rdptr_Generator(
    input logic [15:0] N,
    input logic [15:0] E,
    input logic [15:0] Ko,
    input logic [14:0] bits_per_row,

    input logic ap_clk,
    input logic ap_rst_n,

    output logic [11:0] Read_Ptrs[0:7],
    output logic [3:0] Read_Offsets[0:7],

    output logic [11:0] N_end,
    output logic [3:0] last_word_bit_count,

    input logic [3:0] Q,

    input logic PtrG_in_tvalid,
    output Interleaver_start


);

logic [15:0] Read_Ptrs_N [0:7];
logic [15:0] Read_Ptrs_E [0:7];

assign Read_Ptrs_E[0] = Ko;

    always_comb begin
        for(int i=1;i<8;i++) begin
            Read_Ptrs_E[i] = (Ko+bits_per_row*i)%E;
        end
    end

    always_comb begin
        for (int i=0;i<8 ;i++ ) begin
            if(N>=E) begin
                Read_Ptrs_N[i] = Read_Ptrs_E[i]; 
            end
            else begin
                Read_Ptrs_N[i] = Read_Ptrs_E[i]%N;
            end
        end    
    end




    always_comb begin

        for (int i=0;i<8 ;i++ ) begin
                    Read_Ptrs[i] = 0;
                    Read_Offsets[i] = 0;
            end    

        if(Q==8) begin
            for (int i=0;i<8 ;i++ ) begin
                    Read_Ptrs[i] = Read_Ptrs_N[i]/16;
                    Read_Offsets[i] = Read_Ptrs_N[i]%16;
            end    
        end
        else if(Q==6) begin
            for (int i=0;i<6 ;i++ ) begin
                    Read_Ptrs[i] = Read_Ptrs_N[i]/16;
                    Read_Offsets[i] = Read_Ptrs_N[i]%16;
            end 
        end

        else if(Q==4) begin
            for (int i=0;i<4 ;i++ ) begin
                    Read_Ptrs[2*i] = Read_Ptrs_N[i]/16;
                    Read_Offsets[2*i] = Read_Ptrs_N[i]%16;

                    Read_Ptrs[2*i+1] = Read_Ptrs[2*i]+1>N_end?Read_Ptrs[2*i]-N_end :Read_Ptrs[2*i]+1;

            end 
        end
        else begin
            for (int i=0;i<2 ;i++ ) begin
                    Read_Ptrs[3*i] = Read_Ptrs_N[i]/16;
                    Read_Offsets[3*i] = Read_Ptrs_N[i]%16;

                    Read_Ptrs[3*i+1] = Read_Ptrs[3*i]+1>N_end? Read_Ptrs[3*i]-N_end:Read_Ptrs[3*i]+1;
                    Read_Ptrs[3*i+2] = Read_Ptrs[3*i]+2>N_end? Read_Ptrs[3*i]-N_end+1:Read_Ptrs[3*i]+2;

            end 
        end
    end

        assign Ptrs_valid =1;

        assign N_end = (N-1)/16;
        assign last_word_bit_count = (N%16);


       


endmodule

