

module Packer(
    input  logic           ap_clk,
    input  logic           ap_rst_n,

    input  logic           valid_in,
    input  logic           last_in,
    input  logic [127:0]   data_in,   
    input  logic [6:0]     tkeep,

    output logic ram_write_enables[0:3][0:1],
    output logic [9:0]  ram_addresses[0:3][0:1],
    output logic [17:0] ram_di[0:3][0:1]
);

    

    logic last_in_reg[0:1];
    
    always@(posedge ap_clk) begin
        if(ap_rst_n) begin
            last_in_reg[0] <= 0;
            last_in_reg[1] <= 0;
        end 
        else begin 
            last_in_reg[0] <=last_in;
            last_in_reg[1] <=last_in_reg[0];
        end

    end 

    logic [143:0] buf0;    
    logic [7:0]   fill;  

    logic [143:0] data_lo;   
    logic [127:0] data_hi;   
    logic         spill;
    logic [143:0] data_in_extended = {16'b0,data_in};

    always_comb begin
        data_lo = '0;
        data_hi = '0;

        if (valid_in && !last_in_reg[0]) begin
            if (fill>=tkeep) begin
                data_lo = data_in_extended << (fill - tkeep);
            end else begin
                data_lo = data_in_extended >>(tkeep - fill);
                data_hi = data_in <<(128 + fill- tkeep);
            end
        end
    end

    always_comb begin
        spill   = 1'b0;

        if (valid_in && !last_in_reg[1]) begin
            if (fill>tkeep)  spill   = 1'b0;
            else spill   = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------


    
    assign ram_write_enables[0][0] = spill;
    assign ram_write_enables[0][1] = spill;
    assign ram_write_enables[1][0] = spill;
    assign ram_write_enables[1][1] = spill;
    assign ram_write_enables[2][0] = spill;
    assign ram_write_enables[2][1] = spill;
    assign ram_write_enables[3][0] = spill;
    assign ram_write_enables[3][1] = spill;
    
    wire[143:0] ram_write_data = buf0 | data_lo;

    assign ram_di[0][0] = ram_write_data[143:126];
    assign ram_di[0][1] = ram_write_data[125:108];
    assign ram_di[1][0] = ram_write_data[107:90];
    assign ram_di[1][1] = ram_write_data[89:72];
    assign ram_di[2][0] = ram_write_data[71:54];
    assign ram_di[2][1] = ram_write_data[53:36];
    assign ram_di[3][0] = ram_write_data[35:18];
    assign ram_di[3][1] = ram_write_data[17:0];
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
            ram_write_address[0] <= ram_write_address[0] +1;
            ram_write_address[1] <= ram_write_address[0] +2;
        end
    end
   

    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buf0     <= '0;
            fill     <= 143;
        end 
        else begin
            if (valid_in && !last_in_reg ) begin

                if (spill)  begin
                    buf0 <= {data_hi,16'b0};
                    fill <=143 + fill-tkeep;
                end    
                else begin
                    buf0 <= buf0 | data_lo;
                    fill <= fill -tkeep ;
                end    

            end
        end
    end

endmodule
