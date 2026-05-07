

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

////////////////////////////////// CONFIG ///////////////////////////

    logic config_valid;
    logic config_reset;
    logic cnDataIP_tready;

    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | config_reset) config_valid <=0;
        else if(cnData_tready && cnDataIP_tvalid) config_valid <=1;
        
    end
    
    assign cnData_tready = ap_rst_n && (config_valid==0) && cnDataIP_tready;
    wire cnDataIP_tvalid = cnData_tvalid && (config_valid==0);


    
    logic [63:0] KEC_tdata;
    logic KEC_tvalid;


    KEC_0 KEC (
    .ap_clk(ap_clk),                              // input wire ap_clk
    .ap_rst_n(ap_rst_n),                          // input wire ap_rst_n
    .config_stream_TDATA(cnData_tdata),    // input wire [127 : 0] config_stream_TDATA
    .config_stream_TREADY(cnDataIP_tready),  // output wire config_stream_TREADY
    .config_stream_TVALID(cnDataIP_tvalid),  // input wire config_stream_TVALID
    .out_stream_TDATA(KEC_tdata),          // output wire [31 : 0] out_stream_TDATA
    .out_stream_TREADY(1'b1),        // input wire out_stream_TREADY
    .out_stream_TVALID(KEC_tvalid)        // output wire out_stream_TVALID
    );


    logic [15:0] Ko;
    logic [15:0] E;
    logic KE_valid;
    logic CodeBlock_reset;
    logic [5:0] CodeBlock_counter;
    logic [5:0] Cr;
    logic [5:0] C;
    logic [5:0] sc1;

    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n | CodeBlock_reset) KE_valid <= 0;
        else if(KEC_tvalid) begin
            KE_valid <= 1;
            Ko <= KEC_tdata[31:16];
            E <= KEC_tdata[15:0];
        end
        else if(CodeBlock_reset && CodeBlock_counter ==(Cr-1) )begin
            E <= E + sc1;
        end  

        if(!ap_rst_n | config_reset) CodeBlock_counter <= 0;
        else if(CodeBlock_reset) CodeBlock_counter <= CodeBlock_counter +1;
        
    end

    
////////////////////////////////// AXI CONTROL BLOCK FOR INPUT DATA //////////////////////////////////


     
/////////////////////////////////// AXI CONTROL BLOCK FOR INPUT DATA ///////////////////////////////////  END


    logic [127:0] pData_tdata;
    logic pData_tvalid;
    logic pData_tlast;

    logic run;
    logic done;

    Packer  packer(
        .ap_clk(ap_clk),                              // input wire ap_clk
        .ap_rst_n(ap_rst_n), 


        .inData_tdata(inData_tdata),
        .inData_tkeep(inData_tkeep),
        .inData_tvalid(inData_tvalid),
        .inData_tready(inData_tready),
        .inData_tlast(inData_tlast),

        .outData_tdata(pData_tdata),
        .outData_tvalid(pData_tvalid),
        .outData_tlast(pData_tlast),

        .run(run),
        .done(done),
        .N(N)
    );

    logic [9:0]  address_a[0:3];
    logic [9:0]  address_b[0:3];

    logic [15:0] Dout_a[0:3];
    logic [15:0] Dout_b[0:3];

    logic [15:0] Din_a[0:3];
    logic [15:0] Din_b[0:3];

    logic [9:0] write_address;


    always_ff@(posedge ap_clk)begin
        if(!ap_rst_n) write_address <= 0;
        else if(pData_tvalid) write_address <= write_address +2;
    end

    always_comb begin
        for(int i=0;i<4;i++)begin
            address_a[i] = write_address;
            address_b[i] = write_address+1;
        end
    end

    always_comb begin
        for(int i=0;i<4;i++)begin
            Din_a[i] = pData_tdata[127-16*i-:16];
            Din_b[i] = pData_tdata[63-16*i-:16];
        end
    end
    tdp_bram_4 bram0( 
    .ap_clk(ap_clk),.en(1'b1),.we(outData_tvalid),
    .addra(address_a),.dia(Din_a),.doa(Dout_a),
    .addrb(address_b),.dib(Din_b),.dob(Dout_b)
);


////////////////////////////////////////  WRITE TO FILE ////////////////////////////////////////
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
    
    always @(posedge ap_clk) begin
        if (pData_tvalid) begin
            $fwrite(fd, "%032h\n", pData_tdata);
        end
    end

////////////////////////////////////////  WRITE TO FILE  END////////////////////////////////////////


endmodule




module tdp_bram_4(
    input               ap_clk,
    input               en,
    input               we,
    
    input       [9:0]   addra[0:3],
    input       [15:0]  dia[0:3],
    output reg  [15:0]  doa[0:3],


    input       [9:0]   addrb[0:3],
    input       [15:0]  dib[0:3],
    output reg  [15:0]  dob[0:3]
);

    tdp_bram bram0(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[0]),.dia(dia[0]),.doa(doa[0]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[0]),.dib(dib[0]),.dob(dob[0])
    );

    tdp_bram bram1(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[1]),.dia(dia[1]),.doa(doa[1]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[1]),.dib(dib[1]),.dob(dob[1])
    );

    tdp_bram bram2(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[2]),.dia(dia[2]),.doa(doa[2]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[2]),.dib(dib[2]),.dob(dob[2])
    );

    tdp_bram bram3(
    .clka(ap_clk),.ena(en),.wea(we),.addra(addra[3]),.dia(dia[3]),.doa(doa[3]),
    .clkb(ap_clk),.enb(en),.web(we),.addrb(addrb[3]),.dib(dib[3]),.dob(dob[3])
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
