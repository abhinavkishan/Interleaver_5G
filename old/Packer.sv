

module Packer(
    input  logic           ap_clk,
    input  logic           ap_rst_n,

    input  logic           valid_in,
    input  logic           last_in,
    input  logic [127:0]   data_in,   
    input  logic [6:0]     tkeep,

    output logic ram_write_enable,
    output logic [9:0]  ram_addresses[0:3][0:1],
    output logic [15:0] ram_di[0:3][0:1],
    
    output logic packing_done,
    output logic [15:0] N
);

    logic [127:0] data_in_modified;
    logic last_in_modified;
    logic [6:0] tkeep_modified;

    logic last_register;


    always_comb begin
         if(last_in_modified_reg[0])begin
            tkeep_modified = 127;
            data_in_modified = '0;
         end 
         else begin
            tkeep_modified =  last_register?(N[6:0]-1):tkeep;
             data_in_modified = last_register?buf0:data_in;
         end 
         
         last_in_modified = (N+tkeep_modified+1)>=128?last_in:0; 

        
         
    end



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
    
      
    logic last_in_modified_reg[0:1];
    
    always@(posedge ap_clk) begin
        if(!ap_rst_n) begin
            last_in_modified_reg[0] <= 0;
            last_in_modified_reg[1] <= 0;
        end 
        else begin 
            last_in_modified_reg[0] <=last_in_modified;
            last_in_modified_reg[1] <=last_in_modified_reg[0];
        end
        last_register <= last_in;
    end 

    logic [127:0] buf0;    
    logic [6:0]   free;     
    logic         spill;

    

    always_comb begin
        spill   = 1'b0;
        if(last_in_modified_reg[0] && !last_in_modified_reg[1]) begin
            if(free==7'd127) spill = 0;
            else spill =1;
        end

        else if (valid_in && !last_in_modified_reg[1]) begin
            if (free>tkeep_modified)  spill   = 1'b0;
            else spill   = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------


   
    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buf0     <= '0;
            free     <= 127;
        end 
        else begin
            if (valid_in && !last_in_modified_reg[0] ) begin

                if (spill)  begin
                    buf0 <= data_in_modified;
                    free <=127 + free-tkeep_modified;
                end    
                else begin
                    buf0 <= (buf0<<(tkeep_modified+1)) | data_in_modified;
                    free <= free -tkeep_modified -1;
                end    

            end
        end
    end
    
    
    always@(posedge ap_clk) begin
    
        if(!ap_rst_n) N<=0;
        else if(!last_in_modified_reg[0] && valid_in) N <=  N+tkeep_modified+1;
    
    end


 always @(posedge ap_clk) begin
        if (ram_write_enable) begin
            $fwrite(fd, "%032h\n", ram_write_data);

            $display("write happening");
        end
    end
    
    final begin
        $fclose(fd);
    end
    
    assign packing_done = last_in_modified_reg[1];



         
    assign ram_write_enable = spill;
    wire [127:0] ram_write_data= (buf0<<(free+1)) | (data_in_modified>>(tkeep_modified-free));

    assign ram_di[0][0] = ram_write_data[127:112];
    assign ram_di[0][1] = ram_write_data[111:96];
    assign ram_di[1][0] = ram_write_data[95:80];
    assign ram_di[1][1] = ram_write_data[79:64];
    assign ram_di[2][0] = ram_write_data[63:48];
    assign ram_di[2][1] = ram_write_data[47:32];
    assign ram_di[3][0] = ram_write_data[31:16];
    assign ram_di[3][1] = ram_write_data[15:0];
    logic [9:0] ram_write_address[0:1];

    
    assign ram_addresses[0][0] = ram_write_address[0];
    assign ram_addresses[0][1] = ram_write_address[1];

    assign ram_addresses[1][0] = ram_write_address[0];
    assign ram_addresses[1][1] = ram_write_address[1];

    assign ram_addresses[2][0] = ram_write_address[0];
    assign ram_addresses[2][1] = ram_write_address[1];

    assign ram_addresses[3][0] = ram_write_address[0];
    assign ram_addresses[3][1] = ram_write_address[1];



    always_ff@(posedge ap_clk) begin
        if(!ap_rst_n) begin
             ram_write_address[0] <= 0;
             ram_write_address[1] <= 1;
        end    
        else if(spill) begin
            ram_write_address[0] <= ram_write_address[0] +2;
            ram_write_address[1] <= ram_write_address[1] +2;
        end
    end
   





    
endmodule








/*
module Packer(
    input  logic           ap_clk,
    input  logic           ap_rst_n,

    input  logic           valid_in,
    input  logic           last_in,
    input  logic [127:0]   data_in,   
    input  logic [6:0]     tkeep,

    output logic ram_write_enable,
    output logic [9:0]  ram_addresses[0:3][0:1],
    output logic [15:0] ram_di[0:3][0:1],
    
    output logic packing_done,
    output logic [15:0] N
);

    logic [127:0] data_in_modified;
    logic last_in_modified;
    logic [6:0] tkeep_modified;

    logic last_register;


    always_comb begin
         tkeep_modified =  last_register?(N[6:0]-1):tkeep;
         last_in_modified = (N+tkeep_modified)>=128?last_in:0; 
         data_in_modified = last_register?buf0:data_in;
         
    end



    integer fd;
    initial begin
        fd = $fopen("/home/thrinath/Documents/ram_contents.txt", "w");
        if (fd == 0) begin
            $display("ERROR: Could not open file.");
        end

        else begin
             $display("file opened succesfully");
        end
    end
    
      
    logic last_in_modified_reg[0:1];
    
    always@(posedge ap_clk) begin
        if(!ap_rst_n) begin
            last_in_modified_reg[0] <= 0;
            last_in_modified_reg[1] <= 0;
        end 
        else begin 
            last_in_modified_reg[0] <=last_in_modified;
            last_in_modified_reg[1] <=last_in_modified_reg[0];
        end
        last_register <= last_in;
    end 

    logic [127:0] buf0;    
    logic [6:0]   fill;  

    logic [127:0] data_lo;   
    logic [127:0] data_hi;   
    logic         spill;

    always_comb begin
        data_lo = '0;
        data_hi = '0;

        if (valid_in && !last_in_modified_reg[0]) begin
            if (fill>=tkeep_modified) begin
                data_lo = data_in_modified << (fill - tkeep_modified);
            end else begin
                data_lo = data_in_modified >>(tkeep_modified - fill);
                data_hi = data_in_modified <<(128 + fill- tkeep_modified);
            end
        end
    end

    always_comb begin
        spill   = 1'b0;
        if(last_in_modified_reg[0] && !last_in_modified_reg[1]) begin
            if(fill==7'd127) spill = 0;
            else spill =1;
        end

        else if (valid_in && !last_in_modified_reg[1]) begin
            if (fill>tkeep_modified)  spill   = 1'b0;
            else spill   = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------


    
    assign ram_write_enable = spill;
    
 
     wire [127:0] ram_write_data = buf0 | data_lo;
    
    

    assign ram_di[0][0] = ram_write_data[127:112];
    assign ram_di[0][1] = ram_write_data[111:96];
    assign ram_di[1][0] = ram_write_data[95:80];
    assign ram_di[1][1] = ram_write_data[79:64];
    assign ram_di[2][0] = ram_write_data[63:48];
    assign ram_di[2][1] = ram_write_data[47:32];
    assign ram_di[3][0] = ram_write_data[31:16];
    assign ram_di[3][1] = ram_write_data[15:0];
    logic [9:0] ram_write_address[0:1];

    
    assign ram_addresses[0][0] = ram_write_address[0];
    assign ram_addresses[0][1] = ram_write_address[1];

    assign ram_addresses[1][0] = ram_write_address[0];
    assign ram_addresses[1][1] = ram_write_address[1];

    assign ram_addresses[2][0] = ram_write_address[0];
    assign ram_addresses[2][1] = ram_write_address[1];

    assign ram_addresses[3][0] = ram_write_address[0];
    assign ram_addresses[3][1] = ram_write_address[1];



    always_ff@(posedge ap_clk) begin
        if(!ap_rst_n) begin
             ram_write_address[0] <= 0;
             ram_write_address[1] <= 1;
        end    
        else if(spill) begin
            ram_write_address[0] <= ram_write_address[0] +2;
            ram_write_address[1] <= ram_write_address[1] +2;
        end
    end
   

    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buf0     <= '0;
            fill     <= 127;
        end 
        else begin
            if (valid_in && !last_in_modified_reg[0] ) begin

                if (spill)  begin
                    buf0 <= data_hi;
                    fill <=127 + fill-tkeep_modified;
                end    
                else begin
                    buf0 <= buf0 | data_lo;
                    fill <= fill -tkeep_modified -1;
                end    

            end
        end
    end
    
    
    always@(posedge ap_clk) begin
    
        if(!ap_rst_n) N<=0;
        else if(!last_in_modified_reg[0] && valid_in) N <=  N+tkeep_modified+1;
    
    end


 always @(posedge ap_clk) begin
        if (ram_write_enable) begin
            $fwrite(fd, "%032h\n", ram_write_data);

            $display("write happening");
        end
    end
    
    final begin
        $fclose(fd);
    end
    
    always_ff@(posedge ap_clk) begin
        if(last_in_modified_reg[0] && !last_in_modified_reg[1]) packing_done <= 1;
        else packing_done <=0;

    end
    
endmodule


*/





/*


module Packer(
    input  logic           ap_clk,
    input  logic           ap_rst_n,

    input  logic           valid_in,
    input  logic           last_in,
    input  logic [127:0]   data_in,   
    input  logic [6:0]     tkeep,

    output logic ram_write_enable,
    output logic [8:0]  ram_write_address,
    output logic [127:0] ram_write_data,
    
    output logic packing_done,
    output logic [15:0] N
);

    
    
      
    logic last_in_reg[0:1];
    
    always@(posedge ap_clk) begin
        if(!ap_rst_n) begin
            last_in_reg[0] <= 0;
            last_in_reg[1] <= 0;
        end 
        else begin 
            last_in_reg[0] <=last_in;
            last_in_reg[1] <=last_in_reg[0];
        end

    end 

    logic [127:0] buf0;    
    logic [6:0]   fill;  

    logic [127:0] data_lo;   
    logic [127:0] data_hi;   
    logic         spill;

    always_comb begin
        data_lo = '0;
        data_hi = '0;

        if (valid_in && !last_in_reg[0]) begin
            if (fill>=tkeep) begin
                data_lo = data_in << (fill - tkeep);
            end else begin
                data_lo = data_in >>(tkeep - fill);
                data_hi = data_in <<(128 + fill- tkeep);
            end
        end
    end

    always_comb begin
        spill   = 1'b0;
        if(last_in_reg[0] && !last_in_reg[1]) begin
            if(fill==7'd127) spill = 0;
            else spill =1;
        end

        else if (valid_in && !last_in_reg[1]) begin
            if (fill>tkeep)  spill   = 1'b0;
            else spill   = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------


    
    assign ram_write_enable = spill;
    
 
    ram_write_data = buf0 | data_lo;
    




    always_ff@(posedge ap_clk) begin
        if(!ap_rst_n) begin
             ram_write_address<= 0;
        end    
        else if(spill) begin
            ram_write_address <= ram_write_address +1;
        end
    end
   

    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buf0     <= '0;
            fill     <= 127;
        end 
        else begin
            if (valid_in && !last_in_reg[0] ) begin

                if (spill)  begin
                    buf0 <= data_hi;
                    fill <=127 + fill-tkeep;
                end    
                else begin
                    buf0 <= buf0 | data_lo;
                    fill <= fill -tkeep -1;
                end    

            end
        end
    end
    
    
    always@(posedge ap_clk) begin
    
        if(!ap_rst_n) N<=0;
    
        else if(spill) begin
        
            if(last_in_reg[0] && !last_in_reg[1]) N <= N+(7'd127-fill);
            else N<=N+8'd128;
       
        end
    
    end


 
    
    always_ff@(posedge ap_clk) begin
        if(last_in_reg[0] && !last_in_reg[1]) packing_done <= 1;
        else packing_done <=0;

    end
    
endmodule



*/