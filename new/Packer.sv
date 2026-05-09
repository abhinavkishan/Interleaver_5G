

module Packer(
    input  logic ap_clk,
    input  logic ap_rst_n,

    input  logic [127:0] inData_tdata,
    output logic inData_tready,
    input  logic inData_tvalid,
    input  logic inData_tlast,
    input  logic [6:0] inData_tkeep,

    output  logic [127:0] outData_tdata,
    output  logic outData_tvalid,
    output  logic outData_tlast,




    input logic run,
    output logic done,
    output logic [15:0] N
);

///////////////////////////////////// INPUT AXI LOGIC ///////////////////////////////////////
    logic in_valid_reg;
    logic [127:0] in_data_reg;
    logic [6:0] in_keep_reg;
    logic in_last_reg;

    logic read_over;
    assign inData_tready = ap_rst_n && (!read_over);
    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | (inData_tready && inData_tvalid && inData_tlast)) read_over <=1;
        else if(run) read_over <=0;
    end

    always_ff@(posedge ap_clk)begin
        if(inData_tready && inData_tvalid)begin
            in_valid_reg <= 1;
            in_data_reg <= inData_tdata;
            in_keep_reg <= inData_tkeep;
        end
        else begin
            in_valid_reg <=0;
            in_last_reg <= 0;
        end
    end
///////////////////////////////////// INPUT END LOGIC ///////////////////////////////////////


   


    integer fd;
    initial begin
        fd = $fopen("C:/Users/thrin/Documents/interleaver/ram_contents.txt", "w");
        if (fd == 0) begin
            $display("ERROR: Could not open file.");
        end

        else begin
             $display("file opened succesfully");
        end
    end

    final begin
        $fclose(fd);
    end
    
      
/////////////////////////////////////////////

    

    logic [127:0] buffer;    
    logic [6:0]   free;     
    logic spill;
    logic write_final;
    always_ff@(posedge ap_clk) write_final <= in_last_reg;
    
    always_comb begin
        spill   = 0;
        if(write_final) spill =1;
        else if(in_valid_reg && free<=in_keep_reg) spill   = 1;
    end
    ////////////////////////////////////// SHIFTING LOGIC ////////////////////////////////////
    
    wire [7:0] lsc_temp = 128-in_keep_reg+free;

    wire[6:0] left_shift_count = spill?lsc_temp:(free-in_keep_reg);
    wire [127:0] left_shift_out = in_data_reg << left_shift_count;;

    wire [6:0] right_shift_count = in_keep_reg-free;
    wire [127:0] right_shift_out = in_data_reg >> right_shift_count;

    /// 127 - (k-1) .  k = free - tkeep;  127 - (free - tkeep-1) = 


    
    /////////////////////////////////////// SHIFTING LOGIC END ////////////////////////////////


    logic write_over;
    always_ff@(posedge ap_clk) begin
        if(!ap_rst_n) write_over <= 0;
        else write_over <= in_last_reg;
    end
   
    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buffer <= '0;
            free <= 127;
        end 
        else if (in_valid_reg) begin
            if (spill)  begin   
                if(free == in_keep_reg) buffer <= 0;   
                else buffer <= left_shift_out;
                free <=127 + free-in_keep_reg;
            end    
            else begin
                buffer <= buffer | left_shift_out;
                free <= free -in_keep_reg -1;
            end    
        end
    end


    always_ff @(posedge ap_clk ) begin
        
        if(write_final) outData_tdata <= buffer;
        else if (spill)  outData_tdata <= buffer | right_shift_out;   

        
        if(!ap_rst_n) outData_tvalid <= 0;
        else if(spill)outData_tvalid <= 1;
        else outData_tvalid <= 0;
    end

    
    
    always@(posedge ap_clk) begin
        if(!ap_rst_n) N<=0;
        else if(write_final) N <= N + 7'd127-free;
        else if(spill)N <= N+128;
    end


    
  
    

    

endmodule
