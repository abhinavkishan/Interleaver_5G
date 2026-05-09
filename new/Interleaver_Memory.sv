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




    logic [47:0] storage_in[0:1];
    logic [47:0] storage_out[0:1];
    logic        storage_we[0:1];
    logic [1:0] storage_address[0:1];

    logic [5:0] count_in[0:1];
    logic [5:0] count_out[0:1];
    logic        count_we[0:1];
    logic [1:0] count_address[0:1];

    logic [11:0] addr_in[0:1];
    logic [11:0] addr_out[0:1];
    logic        addr_we[0:1];
    logic [1:0] addr_address[0:1];


        
    LUT_RAM S1 (.clk(ap_clk),.we(storage_we[0]),.addr(storage_address[0]),.din(storage_in[0]),.dout(storage_out[0]));
    LUT_RAM S2 (.clk(ap_clk),.we(storage_we[1]),.addr(storage_address[1]),.din(storage_in[1]),.dout(storage_out[1]));

    LUT_RAM #(.DATA_WIDTH(6)) C1 (.clk(ap_clk),.we(count_we[0]),.addr(count_address[0]),.din(count_in[0]),.dout(count_out[0]));
    LUT_RAM #(.DATA_WIDTH(6)) C2 (.clk(ap_clk),.we(count_we[1]),.addr(count_address[1]),.din(count_in[1]),.dout(count_out[1]));

    LUT_RAM #(.DATA_WIDTH(12)) A1(.clk(ap_clk),.we(addr_we[0]),.addr(addr_address[0]),.din(addr_in[0]),.dout(addr_out[0]));
    LUT_RAM #(.DATA_WIDTH(12)) A2(.clk(ap_clk),.we(addr_we[1]),.addr(addr_address[1]),.din(addr_in[1]),.dout(addr_out[1]));
   ///////////////////////////////  CORE LOGIC /////////////////////////////////////////////////////

    logic pointer_load;

    always_comb begin
        
    end
    always_ff@(posedge ap_clk)begin
        if(pointer_load)begin
            case (Qm)
                2:begin
                    
                end 
                4: 
                6: 
                default: 
            endcase
        end
        else begin
            
        end
    end
    


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

