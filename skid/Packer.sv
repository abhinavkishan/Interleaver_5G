

module Packer(
    input  logic ap_clk,
    input  logic ap_rst_n,

    input  logic [127:0] inData_tdata,
    output logic inData_tready,
    input  logic inData_tvalid,
    input  logic inData_tlast,
    input  logic [6:0] inData_tkeep ,

    output  logic [127:0] pData_tdata,
    output  logic pData_tvalid,
    output  logic pData_tlast,

    input logic trigger,

    output logic [15:0] N,
    output logic N_valid,
    input logic N_ready
);

///////////////////////////////////// INPUT AXI LOGIC ///////////////////////////////////////
    logic in_valid_reg[0:1];
    logic [127:0] in_data_reg;
    logic [6:0] in_keep_reg;
    logic in_last_reg;

    logic read_over;
    assign inData_tready = ap_rst_n && (!read_over);
    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | (inData_tready && inData_tvalid && inData_tlast)) read_over <=1;
        else if(trigger) read_over <=0;
    end

    always_ff@(posedge ap_clk)begin
        in_data_reg <= inData_tdata;
        in_keep_reg <= inData_tkeep;
    
        if(!ap_rst_n | trigger)begin
            in_valid_reg[0] <= 0;
            in_last_reg<= 0;
        end 
        else if(inData_tready && inData_tvalid)begin
            in_valid_reg[0] <= 1;
            in_last_reg <= inData_tlast;
        end 
        else begin
            in_valid_reg[0] <= 0;
            in_last_reg <= 0;
        end 
    

        if(!ap_rst_n | trigger)in_valid_reg[1] <= 0;
        else in_valid_reg[1] <= in_valid_reg[0];
    end

      
/////////////////////////////////////////////
    logic [127:0] buffer;    
    logic [6:0]   free;     
    logic spill;
    logic spill_reg;
    logic write_final;
    logic write_final_reg;
    
    always_ff@(posedge ap_clk) begin
        write_final <= in_last_reg;
        write_final_reg <= write_final;
        spill_reg <= spill;
    end
    
    always_comb begin
        spill   = 0;
        if(write_final) spill =1;
        else if(in_valid_reg[0] && free<=in_keep_reg) spill   = 1;
    end
    ////////////////////////////////////// SHIFTING LOGIC ////////////////////////////////////
    



    
    wire [7:0] lsc_temp = 128-in_keep_reg+free;
    wire [6:0] LSC_STAGE1 = spill?lsc_temp:(free-in_keep_reg);

    logic [4:0] LSC_STAGE2;
    logic [127:0] LS_IN_STAGE1;
    logic BUFFER_SELECT_LINE;

    always_ff@(posedge ap_clk)begin
        if(LSC_STAGE1 >=96)        LS_IN_STAGE1 <= in_data_reg <<96;
        else if(LSC_STAGE1 >=64)   LS_IN_STAGE1 <= in_data_reg <<64;
        else if(LSC_STAGE1 >=32)   LS_IN_STAGE1 <= in_data_reg <<32;
        else                       LS_IN_STAGE1 <= in_data_reg;

        LSC_STAGE2 <= LSC_STAGE1[4:0];
        BUFFER_SELECT_LINE <= free == in_keep_reg;
    end

    wire [127:0] LS_OUT_STAGE2 = LS_IN_STAGE1<<LSC_STAGE2;


    wire [6:0] RSC_STAGE1 = in_keep_reg-free;

    logic [4:0] RSC_STAGE2;
    logic [127:0] RS_IN_STAGE2;

    always_ff@(posedge ap_clk)begin
        if(RSC_STAGE1 >=96)        RS_IN_STAGE2 <= in_data_reg >>96;
        else if(RSC_STAGE1 >=64)   RS_IN_STAGE2 <= in_data_reg >>64;
        else if(RSC_STAGE1 >=32)   RS_IN_STAGE2 <= in_data_reg >>32;
        else                       RS_IN_STAGE2 <= in_data_reg;

        RSC_STAGE2 <= RSC_STAGE1[4:0];
    end

    wire [127:0] RS_OUT_STAGE2 = RS_IN_STAGE2>>RSC_STAGE2;
    
    /////////////////////////////////////// SHIFTING LOGIC END ////////////////////////////////

    logic trigger_reg;
    logic reset_reg;

    always_ff@(posedge ap_clk)begin
        trigger_reg <= trigger;
        reset_reg <= ap_rst_n;
    end 
   
    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n | trigger) free <= 127;
         
        else if (in_valid_reg[0]) begin
            if (spill) free <=127 + free-in_keep_reg; 
            else free <= free -in_keep_reg -1; 
        end
    end

    always_ff @(posedge ap_clk ) begin
        if (!reset_reg | trigger_reg) buffer <= '0;
        else if (in_valid_reg[1]) begin
            if (spill_reg)  begin   
                if(BUFFER_SELECT_LINE) buffer <= 0;   
                else buffer <= LS_OUT_STAGE2;
            end    
            else buffer <= buffer | LS_OUT_STAGE2; 
        end
    end


    always_ff @(posedge ap_clk ) begin
        
        if(write_final_reg)  pData_tdata <= buffer;
        else if (spill_reg) pData_tdata <= buffer | RS_OUT_STAGE2;  
         
        if(!ap_rst_n |trigger) pData_tvalid <= 0;
        else if(spill_reg)pData_tvalid <= 1;
        else pData_tvalid <= 0;

        if(!ap_rst_n | trigger) pData_tlast <= 0;
        else if(write_final_reg) pData_tlast <= 1;
        else pData_tlast <=0;
    end

    
    
    
    always@(posedge ap_clk) begin
        if(!reset_reg | trigger_reg) N<=0;
        else if(write_final_reg) N <= N + 7'd127-free;
        else if(spill_reg)N <= N+128;
    end


    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | trigger) N_valid <= 0;
        else if(write_final_reg) N_valid <= 1;
        else if(N_ready) N_valid <= 0;    
    end
endmodule