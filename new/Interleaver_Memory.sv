module Interleaver_Memory(
    input logic [3:0] Q,    

    input logic [15:0] Din[0:3],
    output logic [9:0] RAM_Address[0:3][0:3],

    

    input logic [14:0] storage_in,
    input logic [3:0] storage_in_keep,
    input logic [11:0] starting_address,

    input logic storage_valid,
    input logic storage_last,

    input logic ap_clk,
    input logic ap_rst_n,

    input logic [11:0] Read_Ptrs,
    input logic [3:0] Offsets,


    output logic [63:0] ImOut_tdata[0:7],
    output logic ImOut_tvalid,
    input  logic Imout_tready
    

);



logic [1:0] state;

logic [9:0] address_array[0:7];
logic [3:0] storage_count_array[0:7];
logic [14:0] storage_array[0:7];
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
        storage_array[p] <= storage_in;
        storage_count_array[p] <= storage_in_keep;
        address_array[p] <= starting_address[11:2];
        cs_array[p] <= starting_address[1:0];
        p <= p + 1;
    end

end

///////////////////////////////////////////////// UNIT 0 /////////////////////////////////////////////////

logic Address[0:3][0:1];


logic [63:0] Backup_unit0[0:1];
logic Backup_valid;

logic row_address[0:3];
logic row_data[0:3];

logic [1:0] cs_address[0:3];
logic [1:0] cs_data[0:3];

logic [3:0] storage_count[0:3];
logic [14:0] storage[0:3];

always_comb begin

    for(int i=0;i<4;i++)begin
        if(row_address[i]==0) begin
            Address[i][0] = address_array[2*i];
            cs_address[i] = cs_array[2*i];
        end
        else begin
            Address[i][0] = address_array[2*i+1];
            cs_address[i] = cs_array[2*i+1];
        end

        Address[i][1] = Address[i][0] +1;
    end

    for(int i=0;i<4;i++)begin

        if(cs_address[i]>=1) RAM_Address[i][0] = Address[i][1];
        else RAM_Address[i][0] = Address[i][0];

        if(cs_address[i]>=2) RAM_Address[i][0] = Address[i][1];
        else RAM_Address[i][0] = Address[i][0];

        if(cs_address[i]==3) RAM_Address[i][0] = Address[i][1];
        else RAM_Address[i][0] = Address[i][0];

        RAM_Address[i][3] = Address[i][0];
    end
end


always_ff@(posedge ap_clk)begin
    for(int i=0;i<4;i++)begin
        cs_data[i] <= cs_address[i];
        row_data[i] <= row_address[i];
    end
end


always_comb begin

    for(int i=0;i<4;i++)begin
        if(row_data[i]==0)begin
            storage[i]= storage_array[2*i];
            storage_count[i]= storage_count_array[2*i];
        end
        else begin
            storage[i] = storage_array[2*i+1];
            storage_count[i] = storage_count_array[2*i+1];
        end
    end
end

always_ff@(posedge ap_clk)begin
    if(state==s1 && storage_valid)begin
        address_array[p] <= starting_address;
    end
    else begin
        
    end
    
end







/////////////////////////////////////////////////ADDRESS HANDLING  END//////////////////////////////////////////////////
logic [15:0] row0_buf;
logic [15:0] row1_buf;


always_ff@



endmodule









module c_s_4 (
    input  logic [15:0] in [0:3],
    input  logic [1:0]  cs,
    output logic [0:63] out
);
    always_comb begin

        for (int i = 0; i < 4; i++) begin
            out[i*16 +: 16] = in[(i + cs)%4];
        end
    end
                             
endmodule

