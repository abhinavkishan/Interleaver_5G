module Interleaver_Memory(
    input logic [3:0] Q,    
    input logic [15:0] Din[0:1][0:3][0:1],
    output logic [9:0] ram_read_adresses[0:1][0:3][0:1],
    output logic [63:0] ram_out[0:7],

    input logic [14:0] storage_in,
    input logic [3:0] storage_in_keep,
    input logic [11:0] starting_address,

    input logic storage_valid,
    input logic storage_last,

    input logic ap_clk,
    input logic ap_rst_n,

    input logic [11:0] Read_Ptrs,
    input logic [3:0] Offsets

);


logic [14:0] storage[0:7];
logic [1:0] state;
logic [3:0] storage_count[0:7];
logic [11:0] address_array[0:7];

logic [1:0] cs_array[0:7];



wire [1:0]s1 = 0;
wire [1:0]s2 = 1;
wire [1:0]s3 = 2;
wire [1:0]s4 = 3;

logic [2:0] p;

always_ff@(posedge ap_clk)begin
    if(!ap_rst_n)begin
        p <= 0;
    end
    else if(state==s1 && storage_valid)begin
        storage[p] <= storage_in;
        storage_count[p] <= storage_in_keep;
        address_array[p] <= starting_address;
        cs_array[p] <= starting_address[1:0];
        p <= p + 1;
    end

end

/////////////////////////////////////////////////ADDRESS HANDLING//////////////////////////////////////////////////









endmodule