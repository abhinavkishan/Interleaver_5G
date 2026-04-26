
module Interleaver_Memory(
    input logic [3:0] Q,    
    input logic [15:0] Din[0:3][0:1][0:3],
    output logic [9:0] ram_read_adresses[0:3][0:1][0:3],

    output logic [15:0] output_reg[0:7],
    output logic Interleaver_Memory_Out_valid,

    input logic ap_clk,
    input logic ap_rst_n,

    input logic start,
    input logic Buffer_ready,

    input logic [11:0] Read_Ptrs[0:7],
    input logic [11:0] N_end,
    input logic [3:0] last_word_bit_count,

    output logic RE,

    input logic [3:0] Offsets[0:7]

);


    logic run;
    logic data_run;
    always@(posedge ap_clk) begin
        if(start)run <=1;
        else if(!ap_rst_n) run<=0;
    end
    
    logic start_reg[0:1];
    always@(posedge ap_clk) begin
        if(!ap_rst_n) begin
            data_run <=0;  start_reg[0]<=0;start_reg[1]<=0;
        end
        else begin
            start_reg[0] <= start; start_reg[1] <= start_reg[0];
            data_run <=run;
        end
    end
    

    wire transaction = Buffer_ready && Interleaver_Memory_Out_valid;
    wire update = run && (transaction | !Interleaver_Memory_Out_valid);
    assign RE  = update;



    

    logic [11:0] bank_adresses[0:7];
    logic [15:0] bank_data_in[0:7][0:3];
    logic [1:0] bank_ram_no[0:7];

    logic stall[0:7];
    logic stall_reg[0:7];

    logic stall_dummy[0:7];
    logic stall_dummy_reg[0:7];

    logic stall_global ;

    logic [3:0]  storage_bit_count[0:7];
    logic [1:0] end_indicator_reg[0:3];
    logic [1:0] end_indicator[0:3];


    logic [11:0] reference[0:3];

    always_comb begin
        if(Q==4) begin
            reference[0] = stall_reg[0] ? bank_adresses[1] :bank_adresses[0];
            reference[1] = stall_reg[2] ? bank_adresses[3] :bank_adresses[2];
            reference[2] = stall_reg[4] ? bank_adresses[5] :bank_adresses[4];
            reference[3] = stall_reg[6] ? bank_adresses[7] :bank_adresses[6];
        end 
        else begin
            reference[0] = stall_reg[0] ? bank_adresses[2] :bank_adresses[0];
            reference[1] = stall_reg[3] ? bank_adresses[5] :bank_adresses[3];

        end
    end



/////////////////////////////////////// ADRESSS MANAGING ////////////////////////////////////////////////////////////////////////

    always@(posedge ap_clk) begin
        if(update) begin
            for(int i=0;i<8;i++) begin
                bank_ram_no[i] <= bank_adresses[i][2:1];    ////// RAM NO SELECTION
            end
        end
    end

    
    
    always_ff@(posedge ap_clk) begin
        if((start)) begin
            for(int i=0;i<8;i++) begin
                bank_adresses[i] <= Read_Ptrs[i];
            end 
        end
        else if(update) begin
        
                if(Q==8)begin
                   for(int i=0;i<8;i++)begin
                        if( start_reg[0] ) begin
                            if(bank_adresses[i]==N_end) begin
                                bank_adresses[i] <=bank_adresses[i] -N_end; 
                            end
                            else if(Offsets[i]!=0 ) begin
                                bank_adresses[i] <=bank_adresses[i] +1;

                            end
                        end

                        else if(stall[2*i]) begin
                            bank_adresses[i] <= bank_adresses[i] -N_end;
                        
                        end
                        else if(!stall_global) begin

                                if(bank_adresses[i]==N_end) bank_adresses[i] <= bank_adresses[i] -N_end;
                                else bank_adresses[i] <=bank_adresses[i] +1;            
                        end
                    end
                end 
                else if(Q==6) begin
                    for(int i=0;i<6;i++) begin
                       if( start_reg[0] ) begin
                            if(bank_adresses[i]==N_end) begin
                                bank_adresses[i] <=bank_adresses[i] -N_end; 
                            end
                            else if(Offsets[i]!=0 ) begin
                                bank_adresses[i] <=bank_adresses[i] +1;

                            end
                        end

                        else if(stall[2*i]) begin
                            bank_adresses[i] <= bank_adresses[i] -N_end;
                        
                        end
                        else if(!stall_global) begin

                                if(bank_adresses[i]==N_end) bank_adresses[i] <= bank_adresses[i] -N_end;
                                else bank_adresses[i] <=bank_adresses[i] +1;            
                        end
                    end
                end
                else if(Q==4) begin
                    for(int i=0;i<4;i++) begin

                        if( start_reg[0] ) begin

                            if((Offsets[2*i]!=0 )| (bank_adresses[3*i]==N_end)) begin
                                if(reference[i]+1 >N_end)  bank_adresses[2*i] <= reference[i] -N_end ;
                                else bank_adresses[2*i] <= reference[i] +1;

                                if(reference[i]+2 >N_end)  bank_adresses[2*i+1] <= reference[i] +1-N_end;
                                else bank_adresses[2*i+1] <= reference[i] +2;

                            end
                        end

                        else if(stall_reg[2*i]) begin
                            if(reference[i]+1 >N_end)  bank_adresses[2*i] <= reference[i] -N_end ;
                            else bank_adresses[2*i] <= reference[i] +1;

                            if(reference[i]+2 >N_end)  bank_adresses[2*i+1] <= reference[i] +1-N_end;
                            else bank_adresses[2*i+1] <= reference[i] +2;

                            
                        end


                        else if(stall[2*i]) begin
                            bank_adresses[2*i+1] <= 12'(1'd1-end_indicator[i][0]);
                        
                        end
                        else if(!stall_global) begin

                                if(bank_adresses[2*i]+2>N_end) bank_adresses[2*i] <= bank_adresses[2*i] +1-N_end;
                                else bank_adresses[2*i] <=bank_adresses[2*i] +2;
                                
                                if(bank_adresses[2*i+1]+2 >N_end) bank_adresses[2*i+1] <= bank_adresses[2*i+1] +1-N_end;
                                else bank_adresses[2*i+1] <=bank_adresses[2*i+1] +2;
                            
                        end
                    end
                end
                else begin 
                    for(int i=0;i<2;i++) begin

                        if( start_reg[0] ) begin

                            if((Offsets[3*i]!=0) | (bank_adresses[3*i]==N_end) ) begin
                                if(reference[i]+1 >N_end)  bank_adresses[3*i] <= reference[i] -N_end ;
                                else bank_adresses[3*i] <= reference[i] +1;

                                if(reference[i]+2 >N_end)  bank_adresses[3*i+1] <= reference[i] +1-N_end;
                                else bank_adresses[3*i+1] <= reference[i] +2;

                                if(reference[i]+3 >N_end)  bank_adresses[3*i+2] <= reference[i] +2-N_end;
                                else bank_adresses[3*i+2] <= reference[i] +3;
                            end
                        end

                        else if(stall_reg[3*i]) begin
                            if(reference[i]+1 >N_end)  bank_adresses[3*i] <= reference[i] -N_end ;
                            else bank_adresses[3*i] <= reference[i] +1;

                            if(reference[i]+2 >N_end)  bank_adresses[3*i+1] <= reference[i] +1-N_end;
                            else bank_adresses[3*i+1] <= reference[i] +2;

                            if(reference[i]+3 >N_end)  bank_adresses[3*i+2] <= reference[i] +2-N_end;
                            else bank_adresses[3*i+2] <= reference[i] +3;
                        end


                        else if(stall[3*i]) begin
                            bank_adresses[3*i+2] <= 12'(2'd2-end_indicator[i]);
                        
                        end
                        else if(!stall_global) begin

                            if(bank_adresses[3*i]+3 >N_end) bank_adresses[3*i] <= bank_adresses[3*i] +2-N_end;
                            else bank_adresses[3*i] <=bank_adresses[3*i] +3;
                            
                            if(bank_adresses[3*i+1]+3 >N_end) bank_adresses[3*i+1] <= bank_adresses[3*i+1] +2-N_end;
                            else bank_adresses[3*i+1] <=bank_adresses[3*i+1] +3;
                            
                            if(bank_adresses[3*i+2]+3 >N_end) bank_adresses[3*i+2] <= bank_adresses[3*i+2] +2-N_end;
                            else bank_adresses[3*i+2] <=bank_adresses[3*i+2] +3;
                        end
                    end
                end  
        end
    end
////////////////////////////// STALL MANAGEMENT ////////////////////////////////

    
    

    logic end_detector[0:3];
    wire no_end  = last_word_bit_count ==0;

    logic start_stall[0:3];


    always_ff@(posedge ap_clk)begin
        if(start) begin
            for(int i=0;i<4;i++) start_stall[0] <= 0;
        end 
        else begin
            if(Q==2) begin
                start_stall[0] <= bank_adresses[0]==N_end;
                start_stall[1] <= bank_adresses[3]==N_end;
            end
            else begin
                start_stall[0] <= bank_adresses[0]==N_end;
                start_stall[1] <= bank_adresses[2]==N_end;
                start_stall[2] <= bank_adresses[4]==N_end;
                start_stall[3] <= bank_adresses[6]==N_end;
            end
            
        end
    end

    always@(posedge ap_clk)begin
        for(int i=0;i<4;i++) begin
            if(update) end_indicator_reg[i] <=end_indicator[i];
        end
    end
    
    always_comb begin

        for(int i=0;i<8;i++) begin
            stall_dummy[i] =0;
            stall[i] =0;

        end
        stall_global =0;

        for(int i=0;i<4;i++) begin
            end_indicator[i] =0;
            end_detector[i] =0;

        end
        if(!no_end) begin
            if(Q==8) begin
                for(int i=0;i<8;i++) begin
                    stall_dummy[i] = (storage_bit_count[i]+last_word_bit_count>=16);
                    stall[i] = (bank_adresses[i] ==N_end)&& (!stall_reg[i]) &&(!stall_dummy[i]);
                end

                stall_global = stall[0] | stall[1] | stall[2] | stall[3] |
                            stall[4] | stall[5] | stall[6] | stall[7] ;
            end

            else if(Q==6) begin
                for(int i=0;i<6;i++) begin
                    stall_dummy[i] = (storage_bit_count[i]+last_word_bit_count>=16);
                    stall[i] = (bank_adresses[i] ==N_end)&& (!stall_reg[i]) &&(!stall_dummy[i]);
                end

                stall_global = stall[0] | stall[1] | stall[2] | stall[3] |
                            stall[4] | stall[5] ;
            end

            else if(Q==4) begin
                for(int i=0;i<4;i++) begin
                    end_detector[i] = (bank_adresses[2*i] == N_end) | (bank_adresses[2*i+1] == N_end)  ;
                    stall_dummy[2*i] = (storage_bit_count[2*i]+last_word_bit_count>=16) && end_detector[i];

                    stall[2*i] = end_detector[i] && (!stall_dummy[2*i]) && (!stall_reg[2*i]);
                    end_indicator[i] = (bank_adresses[2*i+1] == N_end)?1:0;
                end

                stall_global = stall[0] | stall[2] | stall[4] | stall[6] ;
            end

            else begin
                for(int i=0;i<2;i++) begin
                    end_detector[i] = (bank_adresses[3*i] == N_end) | (bank_adresses[3*i+1] == N_end)| (bank_adresses[3*i+2] == N_end) ;
                    stall_dummy[3*i] = (storage_bit_count[3*i]+last_word_bit_count>=16) && end_detector[i] && (!stall_reg[3*i]);

                    stall[3*i] =  end_detector[i] && (!stall_reg[3*i]) && (!stall_dummy[3*i]);
                    end_indicator[i] = (bank_adresses[3*i+2] == N_end)? 2:(bank_adresses[3*i+1] == N_end?1:0);
                end

                stall_global = stall[0] | stall[3] ;
    
            end
        end
    end




    always@(posedge ap_clk) begin
        if(!ap_rst_n | start) begin
            for(int i=0;i<8;i++) begin
                stall_reg[i]<=0;
            end
        end

        else if(update)begin
            for(int i=0;i<8;i++) begin
                stall_reg[i]<=stall[i];
            end
        end
    end

/////////////////////////////////////////// ADRESSS MANAGING  END ///////////////////////////////////////////////////////////////

    
    
/////////////////////////////////////////// STORAGE AND OUTPUT MANAGEMENT ///////////////////////////////////////////////////////











    logic stall_reg_2[0:7];
    logic stall_for_data_global ;
    logic [15:0]  storage[0:7];
    

    logic [15:0] memory_in_final[0:7];

    logic [47:0] temp_for_Q2[0:1];
    logic [31:0] temp_for_Q4[0:3];



    always_comb begin
        
        if(Q==8) begin   
            stall_for_data_global = stall_reg[0] | stall_reg[1] | stall_reg[2] | stall_reg[3] |
                           stall_reg[4] | stall_reg[5] | stall_reg[6] | stall_reg[7] ;
        end
        else if (Q==6) begin
            stall_for_data_global = stall_reg[0] | stall_reg[1] | stall_reg[2] | stall_reg[3] |
                           stall_reg[4] | stall_reg[5] ;
        end
        else if (Q==4) begin
            stall_for_data_global = stall_reg[0] | stall_reg[2] | stall_reg[4] | stall_reg[6] ;
        end
        else  begin
            stall_for_data_global = stall_reg[0] | stall_reg[3] ;
        end
    end



    always_comb begin
             for(int i=0;i<8;i++) begin
                memory_in_final[i] =bank_data_in[i][bank_ram_no[i]];
            end
    end


    always_ff@(posedge ap_clk) begin
       if(!ap_rst_n |start) begin
            for(int i=0;i<8;i++) begin
                stall_reg_2[i]<=0;
                stall_dummy_reg[i] <=0;
            end
       end
       else if(update)begin
            for(int i=0;i<8;i++) begin
                stall_reg_2[i]<=stall_reg[i];
                stall_dummy_reg[i] <=stall_dummy[i];
            end
       end
    end


    always_ff@(posedge ap_clk) begin

        if(!ap_rst_n | start) begin
                
            for(int i=0;i<8;i++) begin
                storage_bit_count[i] <=0;
                storage[i] <=0;
                Interleaver_Memory_Out_valid <=0;
            end
                
        end
        else if(update) begin
            if(Q==8) begin
                for(int i=0;i<8;i++) begin
                     if(start_reg[1] ) begin
                        if(Offsets[i]!=0) storage_bit_count[i] <= 5'd16 - Offsets[i];
                        else if(stall_reg[i])storage_bit_count[i] <= last_word_bit_count- Offsets[i];
            
                         storage[i] <= memory_in_final[i] <<Offsets[i];
                    end

                    else if(stall_reg[i]) begin
                        Interleaver_Memory_Out_valid <=0;
                        storage_bit_count[i] <= storage_bit_count[i] + last_word_bit_count;
            
                        storage[i] <= storage[i] | (memory_in_final[i]>>storage_bit_count[i]);
                    end
                    else if(stall_dummy_reg[i])begin
                        Interleaver_Memory_Out_valid <=1;
                        storage_bit_count[i] <= storage_bit_count[i] + last_word_bit_count-5'd16;
                        
                        storage[i] <= memory_in_final[i] << (16-storage_bit_count[i]);
                        output_reg[i]  <= storage[i]  |(memory_in_final[i]>>storage_bit_count[i]);
                        
                    end
                    else if(!stall_for_data_global)begin
                        Interleaver_Memory_Out_valid <=1;

                        storage[i]<= memory_in_final[i]<<(16-storage_bit_count[i]);
                        output_reg[i] <=storage[i] | (memory_in_final[i]>>storage_bit_count[i]);
                    
                    end
                end
                
                
            end
            else if(Q==6 ) begin
                for(int i=0;i<6;i++) begin
                    if(start_reg[1] ) begin
                        if(Offsets[i]!=0) storage_bit_count[i] <= 5'd16 - Offsets[i];
                        else if(stall_reg[i])storage_bit_count[i] <= last_word_bit_count- Offsets[i];
                         storage[i] <= memory_in_final[i] <<Offsets[i];
                    end

                    else if(stall_reg[i]) begin
                        storage_bit_count[i] <= storage_bit_count[i] + last_word_bit_count;
                        storage[i] <= storage[i] | (memory_in_final[i]>>storage_bit_count[i]);
                    end
                    else if(stall_dummy_reg[i])begin
                    
                        storage_bit_count[i] <= storage_bit_count[i] + last_word_bit_count-5'd16;
                        storage[i] <= memory_in_final[i] << (16-storage_bit_count[i]);
                        output_reg[i]  <= storage[i]  |(memory_in_final[i]>>storage_bit_count[i]);
                        
                    end
                    else if(!stall_for_data_global)begin
                        storage[i]<= memory_in_final[i]<<(16-storage_bit_count[i]);
                        output_reg[i] <=storage[i] | (memory_in_final[i]>>storage_bit_count[i]);
                    
                    end
                end

                if(start_reg[1] | start_reg[0]) begin
                    Interleaver_Memory_Out_valid <=0;
                end
                else if(stall_for_data_global)begin
                    Interleaver_Memory_Out_valid <=0;
                end
                else  Interleaver_Memory_Out_valid <=1;
                
            end
            else if(Q==4 && Buffer_ready && data_run) begin
                for(int i=0;i<4;i++) begin

                    if(start_reg[1]) begin
                        if(start_stall[i]) begin
                            storage_bit_count[2*i] <= last_word_bit_count- Offsets[2*i];
                            storage[2*i] <= memory_in_final[2*i] <<Offsets[2*i];
                        end    
                        if(Offsets[2*i]!=0)begin
                            storage_bit_count[2*i] <= 4'(16 - Offsets[2*i]);
                            storage[2*i] <= memory_in_final[2*i] <<Offsets[2*i];
                        end    
                    end
                    
                    else if(stall_reg[2*i]) begin
                        storage_bit_count[2*i] <= storage_bit_count[2*i] + last_word_bit_count;
                        {storage[2*i],storage[2*i+1]} <= temp_for_Q4[i];
                        
                    end
                    else if(stall_dummy_reg[2*i])begin
        
                        storage_bit_count[2*i] <= storage_bit_count[2*i] + last_word_bit_count-16;

                        if(stall_reg[2*i+1]) storage[2*i] <= memory_in_final[2*i+1] << (16-storage_bit_count[2*i]);
                        else storage[2*i] <= memory_in_final[2*i+1] << (32-storage_bit_count[2*i]-last_word_bit_count);

                        {output_reg[2*i],output_reg[2*i+1]}  <= temp_for_Q4[i];
                        
                        
                    end
                    else if(stall_reg_2[2*i]) begin       
                        {output_reg[2*i],output_reg[2*i+1]} <=
                        {storage[2*i],storage[2*i+1]}  |  ({16'b0,memory_in_final[2*i+1]}>>storage_bit_count[2*i]);

                        storage[2*i] <= memory_in_final[2*i+1] << (16-storage_bit_count[2*i]);

                    end
                    else if(!stall_for_data_global)begin
                        storage[2*i]<= memory_in_final[2*i+1]<<(16-storage_bit_count[2*i]);

                        {output_reg[2*i],output_reg[2*i+1]} <={storage[2*i],16'b0}  | 
                        ({memory_in_final[2*i],memory_in_final[2*i+1]}>>storage_bit_count[2*i]);

                    end

                end

                    if(start_reg[1] | start_reg[0]) begin
                        Interleaver_Memory_Out_valid <=0;
                    end
                    else if(stall_for_data_global)begin
                        Interleaver_Memory_Out_valid <=0;
                    end
                    else  Interleaver_Memory_Out_valid <=1;



            end
            else if(Buffer_ready && data_run) begin
                for(int i=0;i<2;i++) begin
                    if(start_reg[1] ) begin
                        if(start_stall[i])begin
                            storage_bit_count[3*i] <= last_word_bit_count-Offsets[3*i];
                            storage[3*i] <= memory_in_final[3*i] <<Offsets[3*i];
                        end
                        else if(Offsets[3*i]!=0 )begin
                            storage_bit_count[3*i] <= 4'(5'd16 - Offsets[3*i]);
                            storage[3*i] <= memory_in_final[3*i] <<Offsets[3*i];
                        end
                       
                    end
                    else if(stall_reg[3*i]) begin
                        storage_bit_count[3*i] <= storage_bit_count[3*i] + last_word_bit_count;
                        {storage[3*i],storage[3*i+1],storage[3*i+2]} <= temp_for_Q2[i];
                    end
                    else if(stall_dummy_reg[3*i])begin
        
                        storage_bit_count[3*i] <= storage_bit_count[3*i] + last_word_bit_count-16;
                        if(end_indicator_reg[i]==2)storage[3*i] <= memory_in_final[3*i+2] << (16-storage_bit_count[3*i]);
                        else storage[3*i] <= memory_in_final[3*i+2] << (32-storage_bit_count[3*i]-last_word_bit_count); 

                            {output_reg[3*i],output_reg[3*i+1],output_reg[3*i+2]}  <= temp_for_Q2[i];  
                        
                    end
                    else if(stall_reg_2[3*i]) begin        
                        storage[3*i] <= memory_in_final[3*i+2] << (16-storage_bit_count[3*i]);
                        {output_reg[3*i],output_reg[3*i+1],output_reg[3*i+2]} <=
                        {storage[3*i],storage[3*i+1],  (storage[3*i+2] | (memory_in_final[3*i+2]>>storage_bit_count[3*i]))  }; 

                    end
                    else if(!stall_for_data_global)begin
                        storage[3*i]<= memory_in_final[3*i+2]<<(16-storage_bit_count[3*i]);
                        {output_reg[3*i],output_reg[3*i+1],output_reg[3*i+2]} <={storage[3*i],32'b0}  | 
                        ({memory_in_final[3*i],memory_in_final[3*i+1],memory_in_final[3*i+2]}>>storage_bit_count[3*i]);
                    end


                end
                    if(start_reg[1] | start_reg[0]) begin
                        Interleaver_Memory_Out_valid <=0;
                    end
                    else if(stall_for_data_global)begin
                        Interleaver_Memory_Out_valid <=0;
                    end
                    else  Interleaver_Memory_Out_valid <=1;

            end
        end
    end

/////////////////////////////////////

    always_comb begin
        for(int i=0;i<2;i++) begin
            if(end_indicator_reg[i]==2) begin
                temp_for_Q2[i] =      {storage[3*i],32'b0} | 
                ({memory_in_final[3*i],memory_in_final[3*i+1],memory_in_final[3*i+2]}>>storage_bit_count[3*i]);
            end
            else if(end_indicator_reg[i]==1) begin
                temp_for_Q2[i] =     {storage[3*i],32'b0} | 
                (( {memory_in_final[3*i],memory_in_final[3*i+1],16'b0} | ({32'b0, memory_in_final[3*i+2]}<<(16-last_word_bit_count)) )>>storage_bit_count[3*i]);
                
            end
            else begin
                temp_for_Q2[i] =     {storage[3*i],32'b0} | 
                (( {memory_in_final[3*i],32'b0} | ({16'b0,memory_in_final[3*i+1], memory_in_final[3*i+2]}<<(16-last_word_bit_count)) )>>storage_bit_count[3*i]);
            end
        end
    end


/////////////////////////////////////



    always_comb begin
        for(int i=0;i<4;i++) begin

            if(end_indicator_reg[i] ==1) begin
                temp_for_Q4[i] =     {storage[2*i],16'b0} | 
                ( {memory_in_final[2*i], memory_in_final[2*i+1]}>>storage_bit_count[2*i]);
                
            end
            else begin
                temp_for_Q4[i] =     {storage[2*i],16'b0} | 
                (( {memory_in_final[2*i],16'b0} | ({16'b0,memory_in_final[2*i+1]}<<(16-last_word_bit_count)) )>>storage_bit_count[2*i]);
            end
        end
    end








    

    /////////////////////////////////////////// STORAGE AND OUTPUT MANAGEMENT END ///////////////////////////////////////////////////////



    
    always_comb begin
        for(int i=0;i<4;i++) begin
            for(int j=0;j<4;j++) begin
            bank_data_in[i*2][j]    =  Din[j][0][i] ;
            bank_data_in[i*2 +1][j] =  Din[j][1][i] ;

            end
            
        end
    end

    always_comb begin
        for(int i=0;i<4;i++) begin
            for(int j=0;j<4;j++) begin
                ram_read_adresses[j][0][i] = {bank_adresses[i*2][11:3],bank_adresses[i*2][0]};
                ram_read_adresses[j][1][i] = {bank_adresses[i*2 +1][11:3],bank_adresses[i*2+1][0]};

            end
            
        end
    end




endmodule
