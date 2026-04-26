module Interleaver(
    
    input logic [3:0] Q,
    input logic [15:0] Interleaver_Memory_Out[0:7],
    input logic  Interleaver_Memory_Out_valid,

    output logic Buffer_ready,
    
    output logic [95:0] outData_tdata,
    output logic  outData_tvalid,
    output logic  outData_tlast,
    input logic   outData_tready,
    
    input logic ap_clk,
    input logic ap_rst_n,

    input logic Buffer_start,

    input logic [9:0] output_count,
    output logic reset,
    input logic [6:0] output_leftover
    

);  
    logic run;
    logic [11:0] storage[0:7];
    logic [4:0] storage_bit_count;
    wire transaction = outData_tvalid && outData_tready;
    wire update = (transaction| (!outData_tvalid)) && run ;
    logic storage_full;

    

    assign Buffer_ready = outData_tready && run && (!storage_full);

    logic [9:0] output_count_reg;
    logic [6:0] leftover_count_reg;
    always@(posedge ap_clk) begin
        if(!ap_rst_n  | !reset  ) begin 
            output_count_reg <= 0;
            leftover_count_reg<=0;
        end
        else if(Buffer_start) begin
             output_count_reg <= output_count;
             leftover_count_reg <= output_leftover;
        end
    
    end

    wire [6:0] non_zero_count = (output_counter ==(output_count_reg==1?0:output_count_reg-2))?leftover_count_reg:7'd95;


    logic [9:0] output_counter;
    always_comb begin
        if(transaction) reset =  !((output_counter == (output_count_reg-1)) && run) ;
        else reset =1;
    end
   

    always@(posedge ap_clk) begin
        if(output_counter == output_count)  outData_tlast <=1;
        else outData_tlast <=0;

         if(!reset | !ap_rst_n)    output_counter <=0;
         else if(transaction) begin
            if(output_count_reg == output_counter) output_counter <=0;
            else output_counter <= output_counter +1;
         end   
    
    end

    
    
    logic [0:95] out;
    
    always@(posedge ap_clk) begin
        if(Buffer_start) run <=1;
        else if(!ap_rst_n  | !reset  ) run<=0;
    end



    always@(posedge ap_clk) begin
        if(!ap_rst_n | !reset | Buffer_start) outData_tvalid <=0;

        else if(Q==2 | Q==6) begin
            if(update) begin
                if(Interleaver_Memory_Out_valid) begin
                    outData_tdata <= out;
                    outData_tvalid <=1;
                end
                else outData_tvalid <=0;
            end
        end
        else begin
            if(update)begin
                if(storage_full | Interleaver_Memory_Out_valid) begin
                    outData_tdata <= out;
                    outData_tvalid <=1;
                end
                else outData_tvalid <=0;
            end
        end

    end


   
////////////////////////////////////////////////////////

    logic [0:47]rows_Q2[0:1];
    logic [0:23]rows_Q4[0:3];
    logic [0:11]rows_Q8[0:7];
    logic [0:15]rows_Q6[0:5];

    always_comb begin
        for(int i=0;i<2;i++) begin
                rows_Q2[i]  = {Interleaver_Memory_Out[3*i],Interleaver_Memory_Out[3*i+1],Interleaver_Memory_Out[3*i+2]} ;
        end

    end

     always_comb begin
        for(int i=0;i<4;i++) begin
                rows_Q4[i]  = {storage[2*i],storage[2*i+1]} |
                 ({Interleaver_Memory_Out[2*i],Interleaver_Memory_Out[2*i+1][15:8]}>>storage_bit_count);
        end

    end

    always_comb begin
        for(int i=0;i<8;i++) begin
                rows_Q8[i]  = storage[i] | (Interleaver_Memory_Out[i][15:4]>>storage_bit_count);        end

    end

    always_comb begin
        for(int i=0;i<6;i++) rows_Q6[i]  = Interleaver_Memory_Out[i] ;

    end

    
    



    ///////////////////////////////////////////// STORAGE /////////////////////////////////////////////////////////////////

   

    
    always_comb begin
        storage_full =0;
        if(Q==4) storage_full = storage_bit_count ==24;
        else if(Q==8) storage_full = storage_bit_count ==12;
    end

    always@(posedge ap_clk) begin
        if(!ap_rst_n | !reset | (update && storage_full ) )begin
            for(int i =0;i<8;i++) begin
                storage[i] <= 0;
                storage_bit_count<=0;
            end 
        end
        else begin
            if(update && Interleaver_Memory_Out_valid) begin
                storage_bit_count <= storage_bit_count + ((Q==4)?5'd8:5'd4);
                if(Q==4) begin
                    for(int i=0;i<4;i++) begin
                        {storage[2*i],storage[2*i+1]} <= {Interleaver_Memory_Out[2*i][7:0],Interleaver_Memory_Out[2*i+1]} <<(5'd16-storage_bit_count);
                    end
                    
                end
                else begin
                    for(int i=0;i<8;i++) begin
                        storage[i] <= {Interleaver_Memory_Out[i][11:0]} <<(5'd8-storage_bit_count);
                    end
                end
            end
        end
    end

/////////////////////////////////////////////// STORAGE END /////////////////////////////////////////////////////////////////




/////////////////////////////////////////////// OUTPUT FORMATION/////////////////////////////////////////////////////////////////

    always_comb begin


        for(int i=0;i<96;i++) out[i] =0;

        if(Q==8) begin
            for(int i=0;i<12;i++) begin
                for(int j=0;j<8;j++) begin
                    if(8*i+j <=non_zero_count) out[8*i+j] = rows_Q8[j][i];
                end
            end
        end

        else if(Q==6) begin
            for(int i=0;i<16;i++) begin
                for(int j=0;j<6;j++) begin
                   if(6*i+j <=non_zero_count)  out[6*i+j] = rows_Q6[j][i];
                end
            end
        end
        else if(Q==4) begin
            for(int i =0;i<24;i++) begin
                if(4*i <=non_zero_count)   out[4*i] = rows_Q4[0][i];
                if(4*i+1 <=non_zero_count) out[4*i+1] = rows_Q4[1][i];
                if(4*i+2 <=non_zero_count) out[4*i+2] = rows_Q4[2][i];
                if(4*i+3 <=non_zero_count) out[4*i+3] = rows_Q4[3][i];
            end
            
        end
        else begin
            for(int i =0;i<48;i++) begin
                if(2*i <=non_zero_count)   out[2*i] = rows_Q2[0][i];
                if(2*i+1 <=non_zero_count) out[2*i+1] = rows_Q2[1][i];
            end
            
        end
        
    

    end
    
    
/////////////////////////////////////////////// OUTPUT FORMATION/////////////////////////////////////////////////////////////////
   

endmodule






