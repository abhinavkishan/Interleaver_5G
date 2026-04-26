

module Interleaver_shell(
   input  logic [127:0] cnData_tdata,
   output logic cnData_tready,
   input  logic cnData_tvalid,

   input  logic [127:0] inData_tdata,
   output logic inData_tready,
   input  logic inData_tvalid,
   input  logic inData_tlast,
   input  logic [6:0] inData_tkeep,

   output logic [95:0] outData_tdata,
   input  logic outData_tready,
   output logic outData_tvalid,
   output logic outData_tlast,

   input logic ap_clk,
   input logic ap_rst_n
);




    logic internal_reset;
    logic reset;

    assign internal_reset = reset && ap_rst_n;

    
    

////////////////////////////////////// AXI CONTROL BLOCK FOR CnDATA /////////////////////////////////// START

    logic [127:0] cnData_tdata_reg;
    logic cnData_tvalid_reg;


    always_ff @( posedge ap_clk ) begin 
        if(!ap_rst_n)                                cnData_tvalid_reg <=0;
        else if(cnData_tready && cnData_tvalid)     cnData_tvalid_reg <=1;
        else                                        cnData_tvalid_reg <=cnData_tvalid_reg;
    end


    always_ff @( posedge  ap_clk) begin
        if(cnData_tvalid && cnData_tready)      cnData_tdata_reg <= cnData_tdata;      
        else                                    cnData_tdata_reg <= cnData_tdata_reg;
    end

    assign cnData_tready = (ap_rst_n) && (!cnData_tvalid_reg);

///////////////////////////////// AXI CONTROL BLOCK FOR CONFIG DATA //////////////////////////////////// END



////////////////////////////////// AXI CONTROL BLOCK FOR INPUT DATA ////////////////////////////////// START

    logic signed [127:0] inData_tdata_reg;
    logic inData_tvalid_reg;
    logic inData_tlast_reg;
    logic [6:0] inData_tkeep_reg;

    always_ff @(posedge ap_clk) begin
        if(!internal_reset) begin
            inData_tvalid_reg <= 0;
            inData_tlast_reg  <= 0;
        end
        else if(inData_tvalid && inData_tready) begin
            inData_tvalid_reg <= 1;
            inData_tlast_reg  <= inData_tlast;
            inData_tdata_reg <= inData_tdata;
            inData_tkeep_reg <= inData_tkeep;
        end            
         
    end
    
    assign inData_tready = (ap_rst_n)  &&  ((!inData_tlast_reg) |  (!inData_tvalid_reg)) ;
     
/////////////////////////////////// AXI CONTROL BLOCK FOR INPUT DATA ///////////////////////////////////  END



    
    
////////////////////////////////// KE caluculator ///////////////////////////////////  END

    logic [15:0] E,Ko;
    logic ke_done;
    logic [14:0] bits_per_row;
    wire  [3:0] Q = cnData_tdata_reg[23:20];
    logic [9:0] output_count;
    logic [6:0] output_leftover;

    logic config_stream_TREADY;

    logic ke_valid;
    logic [63:0] out_stream_TDATA;
   KE_Calculator_0 ke_calc (
    .ap_clk(ap_clk),                              // input wire ap_clk
    .ap_rst_n(ap_rst_n),                          // input wire ap_rst_n
    .config_stream_TDATA(cnData_tdata_reg),    // input wire [127 : 0] config_stream_TDATA
    .config_stream_TREADY(config_stream_TREADY),  // output wire config_stream_TREADY
    .config_stream_TVALID(cnData_tvalid_reg),  // input wire config_stream_TVALID
    .out_stream_TDATA(out_stream_TDATA),          // output wire [61 : 0] out_stream_TDATA
    .out_stream_TREADY(1'b1),        // input wire out_stream_TREADY
    .out_stream_TVALID(ke_valid)        // output wire out_stream_TVALID
);

    logic E_valid;
    
    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n) begin
            E_valid <=0;
        end
        else if(ke_valid) begin
            E_valid <= 1;
            E <= out_stream_TDATA[63:48];
            Ko <= out_stream_TDATA[47:32];
            bits_per_row <= out_stream_TDATA[31:17];
            output_count <= out_stream_TDATA[16:7];
            output_leftover <= out_stream_TDATA[6:0];
        end
    end

 
    
////////////////////////////////// KE caluculator  END ///////////////////////////////////  END


    logic packing_done;
    logic [15:0] N;

    logic [15:0] ram_di[0:3][0:1];
    logic ram_write_enable;
    logic [9:0]  ram_addresses_packer[0:3][0:1];
    Packer packer(
            .ap_clk(ap_clk),
            .ap_rst_n(internal_reset),

            .valid_in(inData_tvalid_reg),
            .data_in(inData_tdata_reg),
            .last_in(inData_tlast_reg),   
            .tkeep(inData_tkeep_reg),

            .ram_write_enable(ram_write_enable),
            .ram_di(ram_di),
            .ram_addresses(ram_addresses_packer),
            .packing_done(packing_done),
            .N(N)
    );


 ////////////////////////////////// Pointer calc START ///////////////////////////////////  


    wire [66:0] in_data_pc = {E,Ko,N,bits_per_row,Q};
    logic in_valid_pc_reg;

    logic in_valid_pc;
    logic in_ready_pc;
    
    logic [143:0] out_data_pc;
    logic out_valid_pc;
    wire out_ready_pc =1;

    
    always_ff@(posedge ap_clk)begin
        if (!internal_reset) in_valid_pc_reg <=0;
        else if(in_valid_pc) in_valid_pc_reg <=1 ;
    end
    
    always_comb begin
        if(packing_done && E_valid && !in_valid_pc_reg) in_valid_pc =1;
        else in_valid_pc =0;

    end
    
    


Rdptr_Generator_0 pc1(
  .ap_clk(ap_clk),                        // input wire ap_clk
  .ap_rst_n(ap_rst_n),                    // input wire ap_rst_n
  .in_stream_TDATA(in_data_pc),      // input wire [66 : 0] in_stream_TDATA
  .in_stream_TREADY(in_ready_pc),    // output wire in_stream_TREADY
  .in_stream_TVALID(in_valid_pc),    // input wire in_stream_TVALID
  .out_stream_TDATA(out_data_pc),    // output wire [143 : 0] out_stream_TDATA
  .out_stream_TREADY(out_ready_pc),  // input wire out_stream_TREADY
  .out_stream_TVALID(out_valid_pc)  // output wire out_stream_TVALID
);
    logic [11:0] Read_Ptrs[0:7];
    logic [3:0] Read_Offsets[0:7];
    logic [11:0] N_end;
    logic [3:0] last_word_bit_count;
    logic pointers_valid;
    logic Interleaver_start_reg[0:1];

    always@(posedge ap_clk) begin

        for(int i=0;i<8;i++) begin
            Read_Ptrs[i] <= out_data_pc[143-12*i-:12];
        end
        for(int i=0;i<8;i++) begin
            Read_Offsets[i] <= out_data_pc[47-4*i-:4];
        end
        N_end <= out_data_pc[15:4];
        last_word_bit_count <= out_data_pc[3:0];

        if(!internal_reset)  Interleaver_start_reg[0] <=0;
        else if(out_valid_pc) Interleaver_start_reg[0] <= 1;        

        if(!internal_reset)   Interleaver_start_reg[1] <=0;
        else Interleaver_start_reg[1] <=Interleaver_start_reg[0];

    end

    logic Interleaver_start;
    always_comb begin
        if(Interleaver_start_reg[1])  Interleaver_start = 0;
        else Interleaver_start =  Interleaver_start_reg[0];
    end


  
    


////////////////////////////////// Pointer calc START ///////////////////////////////////  
    logic [9:0]  ram_addresses[0:3][0:1][0:3];
    logic [9:0]  ram_addresses_interleaver[0:3][0:1][0:3];

    logic memory_select;
    
    always@(posedge ap_clk) begin
        if(!internal_reset) memory_select<=0;
        else if(packing_done) memory_select <=1;
    
    end
    
    always_comb begin
    
        if(memory_select) begin
        
            ram_addresses = ram_addresses_interleaver;
            ram_enable = RE;
            
        end
        else begin
            ram_enable =1;
            for(int i=0;i<4;i++) begin
                for (int j =0;j<4 ;j++ ) begin
                    ram_addresses[i][0][j] = ram_addresses_packer[i][0];
                     ram_addresses[i][1][j] = ram_addresses_packer[i][1];
                end
            end
           end
    end



    logic ram_enable;
    logic [15:0] ram_do[0:3][0:1][0:3];

tdp_bram_4 bram0( 
    .ap_clk(ap_clk),.en(ram_enable),.we(ram_write_enable),
    .addra(ram_addresses[0][0]),.dia(ram_di[0][0]),.doa(ram_do[0][0]),
    .addrb(ram_addresses[0][1]),.dib(ram_di[0][1]),.dob(ram_do[0][1])
);

tdp_bram_4 bram1( 
    .ap_clk(ap_clk),.en(ram_enable),.we(ram_write_enable),
    .addra(ram_addresses[1][0]),.dia(ram_di[1][0]),.doa(ram_do[1][0]),
    .addrb(ram_addresses[1][1]),.dib(ram_di[1][1]),.dob(ram_do[1][1])
);

tdp_bram_4 bram2( 
    .ap_clk(ap_clk),.en(ram_enable),.we(ram_write_enable),
    .addra(ram_addresses[2][0]),.dia(ram_di[2][0]),.doa(ram_do[2][0]),
    .addrb(ram_addresses[2][1]),.dib(ram_di[2][1]),.dob(ram_do[2][1])
);

tdp_bram_4 bram3( 
    .ap_clk(ap_clk),.en(ram_enable),.we(ram_write_enable),
    .addra(ram_addresses[3][0]),.dia(ram_di[3][0]),.doa(ram_do[3][0]),
    .addrb(ram_addresses[3][1]),.dib(ram_di[3][1]),.dob(ram_do[3][1])
);


    


logic [15:0] Interleaver_Memory_Out[0:7];

logic Interleaver_Memory_Out_valid;
logic RE;
logic Buffer_ready;



Interleaver_Memory interleaver_memory(
    .Q(Q),    
    .Din(ram_do),
    .ram_read_adresses(ram_addresses_interleaver),

    .output_reg(Interleaver_Memory_Out),
    .Interleaver_Memory_Out_valid(Interleaver_Memory_Out_valid),
    .ap_clk(ap_clk),
    .ap_rst_n(internal_reset),

    .start(Interleaver_start),
    .Buffer_ready(Buffer_ready),

    .Read_Ptrs(Read_Ptrs),
    .N_end(N_end),
    .last_word_bit_count(last_word_bit_count),
    .RE(RE),
    .Offsets(Read_Offsets)

);
    
Interleaver interleaver(
    .Q(Q),
    .Interleaver_Memory_Out(Interleaver_Memory_Out),
    .Interleaver_Memory_Out_valid(Interleaver_Memory_Out_valid),

    .Buffer_ready(Buffer_ready),
    .outData_tdata(outData_tdata),
    .outData_tvalid(outData_tvalid),
    .outData_tlast(outData_tlast),
    .outData_tready(outData_tready),
    
    .ap_clk(ap_clk),
    .ap_rst_n(ap_rst_n),

    .Buffer_start(Interleaver_start),
    .reset(reset),
    .output_count(output_count),
    .output_leftover(output_leftover)
    

);




endmodule




module tdp_bram_4(
    input               ap_clk,
    input               en,
    input               we,
    
    input       [9:0]   addra[0:3],
    input       [15:0]  dia,
    output reg  [15:0]  doa[0:3],


    input       [9:0]   addrb[0:3],
    input       [15:0]  dib,
    output reg  [15:0]  dob[0:3]
);

    tdp_bram bram0(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[0]),.dia(dia),.doa(doa[0]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[0]),.dib(dib),.dob(dob[0])
    );

    tdp_bram bram1(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[1]),.dia(dia),.doa(doa[1]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[1]),.dib(dib),.dob(dob[1])
    );

    tdp_bram bram2(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[2]),.dia(dia),.doa(doa[2]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[2]),.dib(dib),.dob(dob[2])
    );

    tdp_bram bram3(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[3]),.dia(dia),.doa(doa[3]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[3]),.dib(dib),.dob(dob[3])
    );

     



endmodule



module tdp_bram(
    input               clka,
    input               ena,
    input               wea,
    input       [9:0]   addra,
    input       [15:0]  dia,
    output reg  [15:0]  doa,

    input               clkb,
    input               enb,
    input               web,
    input       [9:0]   addrb,
    input       [15:0]  dib,
    output reg  [15:0]  dob
);

    // 1024 x 18-bit memory
    reg [15:0] ram [0:1023];

    // Port A
    always @(posedge clka) begin
        if (ena) begin
            if (wea) ram[addra] <= dia;
            else doa <= ram[addra];   
        end
    end

    // Port B
    always @(posedge clkb) begin
        if (enb) begin
            if (web) ram[addrb] <= dib;
            else dob <= ram[addrb];   
        end
    end

endmodule

module KE_Caluculator(
    input logic [127:0] cnData_tdata_reg,
    input logic cnData_tdata_tvalid,
    input logic ap_clk,
    input logic ap_rst_n,
    output logic [15:0] E,
    output logic [15:0] Ko,
    output logic ke_done,
    output logic [14:0] bits_per_row,
    
    output logic [3:0] Q,

    output logic[9:0] output_count,
    output logic [6:0] output_leftover
 );

assign ke_done =1;
assign bits_per_row  = E/Q;

assign output_count = (E+95)/96;
assign output_leftover = (E+95)%96;




  assign Ko =0;
  assign E = 10800;
   assign Q = 6;



endmodule
