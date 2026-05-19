module Interleaver_Memory(
    input logic [35:0] ImConfig_tdata,
    input logic ImConfig_tvalid,
    output logic ImConfig_tready,

    output logic [1:0] IM_frame[0:1],
    output logic [9:0] IM_address[0:1],
    input logic [47:0] IM_data[0:1],

    

    input logic [15:0] pointer_tdata,
    input logic pointer_tvalid,
    


    output logic [95:0] outData_tdata,
    output logic outData_tvalid,
    input  logic outData_tready,
    output logic outData_tlast,

    input logic ap_clk,
    input logic ap_rst_n,

    output logic IM_done
);


    /////////////////////////////////////  CONFIG //////////////////////////////////////////////////

    logic [15:0] N,E;
    logic [3:0] Qm;
    always_ff@(posedge ap_clk)begin
        if(ImConfig_tvalid && ImConfig_tready)begin
            N <= ImConfig_tdata[35:20];
            E <= ImConfig_tdata[19:4];
            Qm <= ImConfig_tdata[3:0];
        end
        else if(transaction && sets_valid)begin
            E <= E-96;
        end

        if(!ap_rst_n | IM_done) ImConfig_tready <= 1;
        else if(ImConfig_tvalid) ImConfig_tready <= 0;    
    end

    logic [1:0] update_interval;
    always_ff@(posedge ap_clk) update_interval <= Qm[3:1]-1;


    logic load_pointers =1;
    logic set_switch=0;

    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | IM_done) load_pointers<= 1;
        else if(ACF_LUT_address[1]==update_interval && set_switch && pointer_tvalid) load_pointers <= 0;    
    end



///////////////////////////////  CORE LOGIC /////////////////////////////////////////////////////

    logic [5:0] CGI_LSC;
    logic [5:0] CGI_valid_bit_count;
    logic [1:0] CGI_frame;
    CGI cgi(.pointer(pointer_tdata),.LSC(CGI_LSC),.valid_bit_count(CGI_valid_bit_count),.frame(CGI_frame),.N(N));

/////////////////////////// ADDRESS MANAGEMENR AND COUNT MANAGEMENT   ///////////////////////////


    logic [17:0] ACF_LUT_in[0:1];
    logic [17:0] ACF_LUT_out[0:1];
    logic        ACF_LUT_we[0:1];
    logic [1:0]  ACF_LUT_address[0:1];
    
    

    logic [9:0] EH_next_address[0:1];
    logic end_detected[0:1];
    
    always_comb begin
        ///////////////  WRITE ENABLES ////////////////////
        if(load_pointers) begin
            ACF_LUT_we[0] = !set_switch;
            ACF_LUT_we[1] = set_switch;
        end
        else begin
            if(global_stall && !stall[0]) ACF_LUT_we[0] =0;
            else ACF_LUT_we[0] =1;

            if(global_stall && !stall[1]) ACF_LUT_we[1] =0;
            else ACF_LUT_we[1] =1;
        end

        /////////////////// IN//////////////////////////

        for(int i=0;i<2;i++) begin
            ACF_LUT_in[i][17:8] =EH_next_address[i];
            ACF_LUT_in[i][1:0] = load_pointers?CGI_frame+1:(end_detected[i]?0:IM_frame[i]+1);
            ACF_LUT_in[i][7:2] = load_pointers?CGI_valid_bit_count:storage_bit_count_updated[i];

        end

    end

    always_comb begin
        for(int i=0;i<2;i++) begin
            IM_address[i] = load_pointers?pointer_tdata[15:6]:ACF_LUT_out[i][17:8];
            IM_frame[i] = load_pointers?CGI_frame:ACF_LUT_out[i][1:0];
        end
    end

//////////////////////////////////////////// STALL,ADDRESS AND BIT COUNT MANAGEMENT //////////////////////////////////////////////////

    wire global_stall = stall[0] | stall[1] ;

    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | IM_done)begin
            ACF_LUT_address[0] <= 0;
            ACF_LUT_address[1] <= 0;
        end
        else if(load_pointers)begin
            if(pointer_tvalid) begin
                if(set_switch) ACF_LUT_address[1] <= ACF_LUT_address[1] +1;
                else ACF_LUT_address[0] <= ACF_LUT_address[0] +1;
            end
        end
        else begin
            for(int i=0;i<2;i++)begin
                if(!global_stall && !stall[i])begin
                    if(ACF_LUT_address[i]==update_interval) ACF_LUT_address[i] <=0;
                    else ACF_LUT_address[i] <= ACF_LUT_address[i]+1;
                end
            end
        end


        if(!ap_rst_n | IM_done)set_switch <= 0;
        else if(load_pointers)begin
           if(ACF_LUT_address[0]==update_interval && pointer_tvalid) set_switch <=1; 
        end
    end



    LUT_RAM #(.DATA_WIDTH(18)) ACF_LUT1(.clk(ap_clk),.we(ACF_LUT_we[0]),.addr(ACF_LUT_address[0]),.din(ACF_LUT_in[0]),.dout(ACF_LUT_out[0]));
    LUT_RAM #(.DATA_WIDTH(18)) ACF_LUT2(.clk(ap_clk),.we(ACF_LUT_we[1]),.addr(ACF_LUT_address[1]),.din(ACF_LUT_in[1]),.dout(ACF_LUT_out[1]));
    
    END_HANDLER EH1(.frame(IM_frame[0]),.address(IM_address[0]),.end_detected(end_detected[0]),.frame_bit_count(frame_bit_count[0]),.N(N),.next_address(EH_next_address[0]));
    END_HANDLER EH2(.frame(IM_frame[1]),.address(IM_address[1]),.end_detected(end_detected[1]),.frame_bit_count(frame_bit_count[1]),.N(N),.next_address(EH_next_address[1]));



/////////////////////STALL MANAGEMENT :  //////////////////////////////
    logic stall[0:1];
    logic [5:0] storage_bit_count_current[0:1];
    always_comb for(int i=0;i<2;i++) storage_bit_count_current[i] = ACF_LUT_out[i][7:2];
    logic [5:0] storage_bit_count_updated[0:1];
    logic [5:0] frame_bit_count[0:1];
    
    always_comb begin
        for(int i=0;i<2;i++)begin
            if(storage_bit_count_current[i]+frame_bit_count[i] >=7'd48)begin
                stall[i]=0;
                storage_bit_count_updated[i] = storage_bit_count_current[i] + frame_bit_count[i]-48;
            end
            else begin
                stall[i] = 1;
                storage_bit_count_updated[i] = storage_bit_count_current[i] + frame_bit_count[i];
            end
        end
    end


    logic [5:0] LSC_storage[0:1][0:1];
    logic [5:0] RSC_storage[0:1][0:1];
    logic [1:0] STORAGE_ADDRESS[0:1][0:1];
    logic STRG_LUT_we[0:1][0:1];
    logic OWen_storage[0:1][0:1];
    logic data_select_storage[0:1][0:1];


    always_ff@(posedge ap_clk)begin
        for(int i=0;i<2;i++) begin
            STORAGE_ADDRESS[i][0] <= ACF_LUT_address[i];
            STORAGE_ADDRESS[i][1] <= STORAGE_ADDRESS[i][0];
        end



        if(load_pointers)begin
            for(int i=0;i<2;i++) begin
                    data_select_storage[i][0]  <= 0;
                    LSC_storage[i][0] <= CGI_LSC;
                    RSC_storage[i][0] <= 'x;
            end
        end
        else begin
            for(int i=0;i<2;i++)begin
                if(stall[i])begin
                    data_select_storage[i][0] <= 1;
                    LSC_storage[i][0] <='x ;
                    RSC_storage[i][0] <= storage_bit_count_current[i];
                end
                else if(!global_stall) begin
                    data_select_storage[i][0] <= 0;
                    LSC_storage[i][0] <= 48-storage_bit_count_current[i];
                    RSC_storage[i][0] <= storage_bit_count_current[i]; 
                end
            end
        end


        if(!ap_rst_n | IM_done)begin
            STRG_LUT_we[0][0] <= 0;
            STRG_LUT_we[1][0] <= 0;

            OWen_storage[0][0] <= 0;
            OWen_storage[1][0] <= 0;
        end
        else if(load_pointers)begin
            for(int i=0;i<2;i++) begin
                OWen_storage[i][0] <= 0;
            end

            STRG_LUT_we[1][0] <= set_switch;
            STRG_LUT_we[0][0] <= !set_switch;
        end
        else begin
            for(int i=0;i<2;i++)begin
                if(stall[i])begin
                    OWen_storage[i][0] <= 0;
                    STRG_LUT_we[i][0] <= 1; 
                end
                else if(global_stall) begin
                    OWen_storage[i][0] <= 0;
                    STRG_LUT_we[i][0] <= 0;   
                end
                else begin
                    OWen_storage[i][0] <= 1; 
                    STRG_LUT_we[i][0] <= 1;   
                end
            end

        end
        

        if(IM_done | !ap_rst_n)begin
            STRG_LUT_we[0][0] <= 0;
            STRG_LUT_we[0][1] <= 0;
            STRG_LUT_we[1][0] <= 0;
            STRG_LUT_we[1][1] <= 0;


            OWen_storage[0][0] <= 0;
            OWen_storage[0][1] <= 0;
            OWen_storage[1][0] <= 0;
            OWen_storage[1][1] <= 0;
        end
        else begin
            for(int i=0;i<2;i++)begin
                data_select_storage[i][1] <= data_select_storage[i][0];
                LSC_storage[i][1] <= LSC_storage[i][0];
                RSC_storage[i][1] <= RSC_storage[i][0];
                OWen_storage[i][1] <= OWen_storage[i][0];
                STRG_LUT_we[i][1] <= STRG_LUT_we[i][0] ;
            end
        end
    end
    


////////////////////////// STORAGE MANAGEMENT///////////////////////////////
    


    logic [47:0] STRG_LUT_in[0:1];
    logic [47:0] STRG_LUT_out[0:1]; 
    LUT_RAM S1 (.clk(ap_clk),.we(STRG_LUT_we[0][1]),.addr(STORAGE_ADDRESS[0][1]),.din(STRG_LUT_in[0]),.dout(STRG_LUT_out[0]));
    LUT_RAM S2 (.clk(ap_clk),.we(STRG_LUT_we[1][1]),.addr(STORAGE_ADDRESS[1][1]),.din(STRG_LUT_in[1]),.dout(STRG_LUT_out[1]));



    
    
    

    logic [47:0] D1_storage[0:1];
    logic [47:0] D2_storage[0:1];
    always_comb begin
        for(int i=0;i<2;i++)begin
            D1_storage[i] =IM_data[i]<<LSC_storage[i][1] ;
            D2_storage[i] = STRG_LUT_out[i]| (IM_data[i]>>RSC_storage[i][1]);
            if(data_select_storage[i][1]) STRG_LUT_in[i] = D2_storage[i];
            else STRG_LUT_in[i] = D1_storage[i];
        end 
    end

    

    always_ff@(posedge ap_clk)begin
        for(int i= 0;i<2;i++)begin
           if(OWen_storage[i][1])STORAGE_OUTPUT[i][STORAGE_ADDRESS[i][1]] <= D2_storage[i];
        end 
    end

    logic [47:0] STORAGE_OUTPUT[0:1][0:3];


    logic rows_consuming;
    logic  ROWS_BACKUP_VALID[0:7];

    always_ff@(posedge ap_clk)begin

        if(!ap_rst_n | IM_done)begin
            for(int i=0;i<7;i++)begin
                ROWS_BACKUP_VALID[i] <= 0;
            end
        end
        else begin
            for(int i=0;i<8;i++)begin
                if(OWen_storage[i/4][1] && STORAGE_ADDRESS[i/4][1]==i%4)begin
                    ROWS_BACKUP_VALID[i] <=1;
                end
                else if(rows_consuming)begin
                    ROWS_BACKUP_VALID[i]  <=0;
                end
            end
        end
    end
    
    logic BACKUP_VALID;
    always_comb begin
        case (Qm)
            2:        BACKUP_VALID = ROWS_BACKUP_VALID[0] &&                                                                         ROWS_BACKUP_VALID[4] ;      
            4:        BACKUP_VALID = ROWS_BACKUP_VALID[0] && ROWS_BACKUP_VALID[1] &&                                                 ROWS_BACKUP_VALID[4] && ROWS_BACKUP_VALID[5] ;       
            6:        BACKUP_VALID = ROWS_BACKUP_VALID[0] && ROWS_BACKUP_VALID[1] && ROWS_BACKUP_VALID[2] &&                         ROWS_BACKUP_VALID[4] && ROWS_BACKUP_VALID[5] && ROWS_BACKUP_VALID[6] ;       
            default:  BACKUP_VALID = ROWS_BACKUP_VALID[0] && ROWS_BACKUP_VALID[1] && ROWS_BACKUP_VALID[2] && ROWS_BACKUP_VALID[3] && ROWS_BACKUP_VALID[4] && ROWS_BACKUP_VALID[5] && ROWS_BACKUP_VALID[6] && ROWS_BACKUP_VALID[7];       

        endcase
    end
    

////////////////////////// STORAGE MANAGEMENT END///////////////////////
    logic [47:0] rows_backup[0:7];
    
    always_comb begin
        for(int i=0;i<8;i++)begin
            rows_backup[i] = STORAGE_OUTPUT[i/4][i%4];
        end
    end


////////////////////////////////// LUMP BITS AND ROWS UPDATE /////////////////////////////////////
    
    logic [47:0] rows[0:7];  
    logic rows_valid; 
    logic [1:0] sc;
    assign rows_consuming = (sc==update_interval) && BACKUP_VALID;

    always_ff@(posedge ap_clk)begin        
        if(!ap_rst_n | IM_done)begin
            sc <= 0;
            rows_valid <= 0;
        end    
        else if(sc==update_interval)begin
            if(BACKUP_VALID)begin
                for(int i= 0;i<8;i++)begin
                    rows[i] <= rows_backup[i];
                end
                rows_valid <= 1;
                sc <= 0;
            end
            else  rows_valid <= 0;
        end
        else sc <= sc+1;
    end

    logic [47:0] sets[0:1];
    logic sets_valid;
    always@(posedge ap_clk)begin
        if(rows_valid && outData_tready)begin
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
        

        if(!ap_rst_n | IM_done)begin
            sets_valid <= 0;
        end
        else if(rows_valid)begin
            sets_valid <= 1;
        end
    end
/////////////////////////////// LUMP BITS AND ROWS UPDATE  END ///////////////////////////////////


//////////////////////////////////////  FINAL OUTPUT ///////////////////////////////

logic [6:0] output_bit_count;


always_comb begin
    if(E>=96) output_bit_count  = 96;
    else output_bit_count = E;
end


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
    for(int i=0;i<96;i++)begin
        outdata_wire[i] = 0;
    
        if(i<output_bit_count)begin
            case(Qm)
                2:       outdata_wire[i] = rows_Q2[i%2][i/2];
                4:       outdata_wire[i] = rows_Q4[i%2][i/4];   
                6:       outdata_wire[i] = rows_Q6[i%6][i/6];       
                default: outdata_wire[i] = rows_Q8[i%8][i/8];
            endcase
        end
    end
end


/////////////////////////////////////// OUTPUT AXI ////////////////////////////////////

    logic output_done;
    wire sets_valid_gated = (output_done==0) && sets_valid;

    wire transaction = (outData_tready && outData_tvalid) | (outData_tvalid==0);
    always_ff@(posedge ap_clk)begin
        if(transaction && sets_valid_gated) begin
                outData_tdata <= outdata_wire;
        end

        if(!ap_rst_n | IM_done)begin
            outData_tvalid <= 0;
            output_done <= 0;
            outData_tlast <= 0;
        end
        else if(transaction) begin
            if(sets_valid_gated) outData_tvalid <= 1;
            else outData_tvalid <= 0;
            
            if(output_bit_count <96) output_done <= 1;

            if(sets_valid_gated==0) outData_tlast <=0;
            else begin
                if(output_bit_count>=96) outData_tlast <= 0;
                else outData_tlast <= 1;
            end
        end
    end



    
logic [0:95] output_reference[0:10000];
int output_counter=0;
logic [0:11] rows_reference[0:7];
initial begin
    $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_Interleaver_out",output_reference);
    for(int i=0;i<12;i++)begin
        for(int j=0;j<8;j++)begin
            rows_reference[j][i] = output_reference[0][i*8+j];
        end 
    end

end


always_ff@(posedge ap_clk)begin
    if(outData_tvalid)begin
        output_counter = output_counter+1;
        for(int i=0;i<12;i++)begin
            for(int j=0;j<8;j++)begin
                rows_reference[j][i] = output_reference[output_counter][i*8+j];
            end 
        end
    end
end



/////////////////////////////////////// OUTPUT AXI END  ////////////////////////////////////


/////////////////////////////// FINAL OUTPUT END ////////////////////////////////////


    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n) IM_done <= 0;
        else if(outData_tvalid && outData_tlast && outData_tready) IM_done <= 1;
        else IM_done <= 0; 
    end
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



module CGI(   
    input logic [15:0] pointer,
    output logic [5:0] LSC,
    output logic [5:0] valid_bit_count,
    output logic [1:0] frame,

    input logic [15:0] N

);

    wire [11:0] address = pointer[15:4];
    wire [3:0] offset = pointer[3:0];
    wire [1:0] segment = address[1:0];

    assign frame = segment==3?1:0;

///////////////// LEFT SHIFT COUNT ////////////////////////
     always_comb begin
        case (segment)
            0:LSC = offset; 
            1:LSC = 16+offset;
            2:LSC = 32+offset;
            3:LSC = offset;
        endcase
    end
    
///////////////// LEFT SHIFT COUNT  END////////////////////////

///////////////// VALID BIT COUNT ////////////////////////
    wire [11:0] N_end = N[15:4];
    wire [3:0] N_end_count = N[3:0];
    
    always_comb begin
        case (segment)
            0:begin
                if(address==N_end) valid_bit_count = 6'(N_end_count) - 6'(offset);
                else if (address+1==N_end) valid_bit_count = 6'd16 + 6'(N_end_count) - 6'(offset);
                else if(address+2==N_end) valid_bit_count = 32 + 6'(N_end_count) - 6'(offset);
                else  valid_bit_count = 6'd48-6'(offset);
            end 
            1:begin
                if(address==N_end) valid_bit_count = 6'(N_end_count) - 6'(offset);
                else if (address+1==N_end) valid_bit_count = 16 + 6'(N_end_count) - 6'(offset);
                else  valid_bit_count = 6'd32-6'(offset);
            end
            2:begin
                if(address==N_end) valid_bit_count = 6'(N_end_count)-6'(offset);
                else  valid_bit_count = 6'd16-6'(offset);
            end
        
            3: begin
                if(address==N_end) valid_bit_count = 6'(N_end_count) - 6'(offset);
                else if (address+1==N_end) valid_bit_count = 6'd16 + 6'(N_end_count) - 6'(offset);
                else if(address+2==N_end) valid_bit_count = 32 + 6'(N_end_count) - 6'(offset);
                else  valid_bit_count = 6'd48-6'(offset);
            end
        endcase
    end
    
endmodule



module END_HANDLER(
    input logic [1:0] frame,
    input logic [9:0] address,

    output logic end_detected,
    output logic [5:0] frame_bit_count,
    input logic  [15:0] N,

    output logic [9:0] next_address
);

    logic [11:0] target_address[0:2];
    logic [1:0] word_offset;

    wire [11:0] N_end_address = N[15:4];
    wire [3:0] N_end_count = N[3:0];

    


    always_comb begin
        if(end_detected) next_address = 0;
        else begin
            case (frame)
                0: next_address = address;
                1: next_address = address+1;
                2: next_address = address+1;
                3: next_address = address+1;
            endcase
        end
    end



    always_comb begin

        case (frame)
            0: word_offset = 0;
            1: word_offset = 3;
            2: word_offset = 2;
            3: word_offset = 1;
        endcase
        target_address[0] = {address,word_offset};
        target_address[1] = target_address[0]+1;
        target_address[2] = target_address[0]+2;
    end

    always_comb begin
        if(target_address[0]==N_end_address)begin
            frame_bit_count = 6'(N_end_count);
            end_detected= 1;
        end
        else if(target_address[1]==N_end_address)begin
            frame_bit_count = 6'(N_end_count)+16;
            end_detected= 1;
        end
        else if(target_address[2]==N_end_address)begin
            frame_bit_count = 6'(N_end_count)+32;
            end_detected= 1;
        end
        else begin
            frame_bit_count = 48;
            end_detected= 0;
        end
    end                    



endmodule 
