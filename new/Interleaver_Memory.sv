module Interleaver_Memory(
    input logic [3:0] Q,    

    input logic [15:0] Din[0:1][0:3],
    output logic [9:0] Address[0:1][0:3],


    

    input logic [9:0] pointers,
    input logic pointers_valid,

    input logic storage_valid,
    input logic storage_last,

    input logic ap_clk,
    input logic ap_rst_n,


    output logic outData_tdata,
    output logic outData_tvalid,
    input  logic outData_tready,
    output logic outData_tlast,

);
    logic [3:0] Qm;
    always@(posedge ap_clk) Qm <= Q;

    wire pointers_read =0;
    logic [1:0] state;
    logic [2:0] count;

    always@(posedge ap_clk)begin
        if(!ap_rst_n)begin
            count <=0;
        end
        else if(pointers_valid)begin
            count <= count+1;
        end
        if(state == pointers_read)begin
            
        end
    end


    logic [47:0] S1_DATA_IN;
    logic [47:0] S1_DATA_OUT;
    logic        S1_DATA_WE;
    logic [1:0] S1_DATA_ADDRESS;

    logic [47:0] S2_DATA_IN;
    logic [47:0] S2_DATA_OUT;
    logic        S2_DATA_WE;
    logic [1:0] S2_DATA_ADDRESS;


    logic [9:0] A1_DATA_IN;
    logic [9:0] A1_DATA_OUT;
    logic        A1_DATA_WE;
    logic [1:0] A1_DATA_ADDRESS;

    logic [9:0] A2_DATA_IN;
    logic [9:0] A2_DATA_OUT;
    logic        A2_DATA_WE;
    logic [1:0] A2_DATA_ADDRESS;


        
    LUT_RAM S1 (
        .clk(ap_clk),
        .we(S1_DATA_WE),    // Write Enable
        .addr(S1_DATA_ADDRESS),  // Address bus
        .din(S1_DATA_IN),   // Data input
        .dout(S1_DATA_OUT)   // Data output
    );


    LUT_RAM S2 (
        .clk(ap_clk),
        .we(S2_DATA_WE),    // Write Enable
        .addr(S2_DATA_ADDRESS),  // Address bus
        .din(S2_DATA_IN),   // Data input
        .dout(S2_DATA_OUT)   // Data output
    );


    LUT_RAM #(.DATA_WIDTH(10)) A1(
        .clk(ap_clk),
        .we(A1_DATA_WE),    // Write Enable
        .addr(A1_DATA_ADDRESS),  // Address bus
        .din(A1_DATA_IN),   // Data input
        .dout(A1_DATA_OUT)   // Data output
    );
    LUT_RAM #(.DATA_WIDTH(10)) A2(
        .clk(ap_clk),
        .we(A2_DATA_WE),    // Write Enable
        .addr(A2_DATA_ADDRESS),  // Address bus
        .din(A2_DATA_IN),   // Data input
        .dout(A2_DATA_OUT)   // Data output
    );

    /////////////////////////////// EXTERNAL MEMORY HANDLING //////////////////////////

    



   ///////////////////////////////  CORE LOGIC //////////////////////////////////////

    logic [47:0] DATA[0:1][0:7];
    


    ////////////////////////////////// LUMP BITS AND ROWS UPDATE /////////////////////////////////////
    logic [47:0] rows_backup[0:7];
    logic [47:0] rows[0:7];
    logic [1:0] update_interval = Qm[3:1]-1;
    logic [1:0] update_counter;

    always_ff@(posedge ap_clk)begin
        update_counter <= (update_counter==update_interval)? 0:update_counter+1;
        if(update_counter==update_interval)begin
            for(int i= 0;i<8;i++)begin
                rows[i] <= rows_backup[i];
            end
        end
    end

    logic [47:0] sets[0:1];
    logic [1:0] sc;
    always@(posedge ap_clk)begin
        case (Qm)
            2:begin
                sets[0] <= rows[0];
                sets[1] <= rows[4];
            end 
            4:begin
                case(sc)
                    0: begin
                        for(int i=0;i<2;i++)begin
                            sets[0][47-24*i-:24] <= rows[i][47-:24];
                            sets[1][47-24*i-:24] <= rows[4+i][47-:24];
                        end
                    end
                    default: begin
                        for(int i=0;i<2;i++)begin
                            sets[0][47-24*i-:24] <= rows[i][23-:24];
                            sets[1][47-24*i-:24] <= rows[4+i][23-:24];
                        end
                    end
                endcase
            end
            6:begin
                case(sc)
                    0: begin
                        for(int i=0;i<3;i++)begin
                            sets[0][47-16*i-:16] <= rows[i][47-:16];
                            sets[1][47-16*i-:16] <= rows[4+i][47-:16];
                        end
                    end
                    1: begin
                        for(int i=0;i<3;i++)begin
                            sets[0][47-16*i-:16] <= rows[i][31-:16];
                            sets[1][47-16*i-:16] <= rows[4+i][31-:16];
                        end
                    end
                    default: begin
                        for(int i=0;i<3;i++)begin
                            sets[0][47-16*i-:16] <= rows[i][15-:16];
                            sets[1][47-16*i-:16] <= rows[4+i][15-:16];
                        end
                    end
                endcase
                
            end
            default: begin
                case(sc)
                    0: begin
                        for(int i=0;i<4;i++)begin
                            sets[0][47-12*i-:12] <= rows[i][47-:12];
                            sets[1][47-12*i-:12] <= rows[4+i][47-:12];
                        end
                    end
                    1: begin
                        for(int i=0;i<4;i++)begin
                            sets[0][47-12*i-:12] <= rows[i][35-:12];
                            sets[1][47-12*i-:12] <= rows[4+i][35-:12];
                        end
                    end
                    2: begin
                        for(int i=0;i<4;i++)begin
                            sets[0][47-12*i-:12] <= rows[i][23-:12];
                            sets[1][47-12*i-:12] <= rows[4+i][23-:12];
                        end
                    end
                    default: begin
                        for(int i=0;i<4;i++)begin
                            sets[0][47-12*i-:12] <= rows[i][11-:12];
                            sets[1][47-12*i-:12] <= rows[4+i][11-:12];
                        end
                    end
                endcase
            end
        endcase
    end





/////////////////////////////// LUMP BITS AND ROWS UPDATE  END ///////////////////////////////////


//////////////////////////////////////  FINAL OUTPUT ///////////////////////////////


logic [0:95] outdata_wire;

logic [0:47] rows_Q2[0:1];
logic [0:23] rows_Q4[0:3];
logic [0:15] rows_Q6[0:5];
logic [0:11] rows_Q8[0:7];


always_comb begin
    rows_Q2[0] =sets[0];
    rows_Q2[1] =sets[1];

    for(int i=0;i<2;i++)begin
        rows_Q4[i] = sets[0][47-24*i-:24];
        rows_Q4[2+i] = sets[1][47-24*i-:24];;
    end

    for(int i=0;i<3;i++)begin
        rows_Q6[i] = sets[0][47-16*i-:16];
        rows_Q6[3+i] = sets[1][47-16*i-:16];
    end

    for(int i=0;i<4;i++)begin
        rows_Q8[i] = sets[0][47-12*i-:12];
        rows_Q8[4+i] = sets[1][47-12*i-:12];
    end
end

always_comb begin
    case(Qm)
        2:begin
            for(int i=0;i<96;i++)begin
                outdata_wire[i] = rows_Q2[i%2][i/2];
            end
        end
        4:begin
            for(int i=0;i<96;i++)begin
                outdata_wire[i] = rows_Q4[i%2][i/4];
            end
        end
        6:begin
            for(int i=0;i<96;i++)begin
                outdata_wire[i] = rows_Q6[i%6][i/6];
            end
        end
        default:begin
            for(int i=0;i<96;i++)begin
                outdata_wire[i] = rows_Q8[i%8][i/8];
            end
        end

    endcase
end











/////////////////////////////// FINAL OUTPUT END ////////////////////////////////////

endmodule

module LUT_RAM #(
    parameter ADDR_WIDTH = 2,
    parameter DATA_WIDTH = 48,
    parameter DEPTH = 4
)(
    input                     clk,
    input                     we,    // Write Enable
    input  [ADDR_WIDTH-1:0]   addr,  // Address bus
    input  [DATA_WIDTH-1:0]   din,   // Data input
    output [DATA_WIDTH-1:0]   dout   // Data output
);

    // Declare the memory array
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // Synchronous Write Logic
    always @(posedge clk) begin
        if (we) begin
            ram[addr] <= din;
        end
    end

    // Asynchronous Read Logic (The "Distributed" part)
    // This makes it combinational, forcing the tool to use LUT RAM
    assign dout = ram[addr];







endmodule


/*


logic [31:0] mem_reg[0:7];
logic mem_update;
logic mem_select;

always_ff@(posedge ap_clk)begin

    if(!ap_rst_n) begin
        mem_update <=0;
        mem_select <=0;
    end
    if(mem_update)begin
        for(int i=0;i<8;i++)begin
            mem_reg[i] <= {Din[i][2*mem_select],Din[i][2*mem_select+1]};
        end
    end
end


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
/*
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
*/
//////////////////// OUTPUT //////////////////////////////////////////

/*

    logic [15:0] out_wire[0:7];
    logic [14:0] storage[0:7];
    logic [3:0] storage_bit_count[0:7];
    logic [15:0] data[0:7];
    logic [2:0] Qm;
    always_comb begin
        if(Qm==8)begin
            for(int i=0;i<8;i++)begin
                out_wire[i] ={storage[i],1'b0} | (data[i]>>storage_bit_count);
            end
        end    
    
    end



    logic output_valid;
    logic output_update;

    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n) output_valid <=0;
        else if(output_update) begin
            
        end
    end


    */
