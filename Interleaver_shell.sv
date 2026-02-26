

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
        if(!ap_rst_n) begin
            inData_tvalid_reg <= 0;
            inData_tlast_reg  <= 0;
        end
        else if(inData_tvalid && inData_tready) begin
            inData_tvalid_reg <= 1;
            inData_tlast_reg  <= inData_tlast;
        end   

        else begin
            inData_tvalid_reg <= inData_tvalid_reg;
            inData_tlast_reg  <= inData_tlast_reg;
        end          
         
    end

    always_ff @( posedge  ap_clk) begin
        if(inData_tvalid && inData_tready) begin
            inData_tdata_reg <= inData_tdata;
            inData_tkeep_reg <= inData_tkeep;
        end
        else begin
            inData_tdata_reg <= inData_tdata_reg;
            inData_tkeep_reg <= inData_tkeep_reg;
        end
    end
    
    assign inData_tready = (ap_rst_n)  && (!inData_tlast_reg)  ;
     
/////////////////////////////////// AXI CONTROL BLOCK FOR INPUT DATA ///////////////////////////////////  END



     logic         ram_write_enable;
     logic [8:0]   ram_write_address;
     logic [127:0] ram_write_data;

     logic         ram_read_enable;
     logic [8:0]   ram_read_address;
     logic [127:0] ram_read_data ;

    
    
    logic [15:0] E,Ko;
    logic [3:0] Ko_segment,Ko_offset;
    logic [8:0] Ko_word;
    logic ke_done;
    logic [10:0] dozen_count;
    logic [3:0] colomn_end_count;
    KE_Caluculator KE_caluculator(
        .cnData_tdata_reg(cnData_tdata_reg),.ap_clk(ap_clk),.ap_rst_n(ap_rst_n),
        .ke_done(ke_done),.E(E),.Ko(Ko),.Ko_segment(Ko_segment),.Ko_word(Ko_word),
        .Ko_offset(Ko_offset),.dozen_count(dozen_count),.colomn_end_count(colomn_end_count)
    );
    


    

logic ram_enables[0:3][0:1];
logic ram_write_enables[0:3][0:1];
logic [9:0]  ram_addresses[0:3][0:1];
logic [17:0] ram_di[0:3][0:1];
logic [17:0] ram_do[0:3][0:1];


tdp_bram bram1(
    .clka(ap_clk),.ena(ram_enables[0][0]),.wea(ram_write_enables[0][0]),.addra(ram_addresses[0][0]),.dia(ram_di[0][0]),.doa(ram_do[0][0]),
    .clkb(ap_clk),.enb(ram_enables[0][1]),.web(ram_write_enables[0][1]),.addrb(ram_addresses[0][1]),.dib(ram_di[0][1]),.dob(ram_do[0][1])
);
   
tdp_bram bram2(
    .clka(ap_clk),.ena(ram_enables[1][0]),.wea(ram_write_enables[1][0]),.addra(ram_addresses[1][0]),.dia(ram_di[1][0]),.doa(ram_do[1][0]),
    .clkb(ap_clk),.enb(ram_enables[1][1]),.web(ram_write_enables[1][1]),.addrb(ram_addresses[1][1]),.dib(ram_di[1][1]),.dob(ram_do[1][1])
);

tdp_bram bram3(
    .clka(ap_clk),.ena(ram_enables[2][0]),.wea(ram_write_enables[2][0]),.addra(ram_addresses[2][0]),.dia(ram_di[2][0]),.doa(ram_do[2][0]),
    .clkb(ap_clk),.enb(ram_enables[2][1]),.web(ram_write_enables[2][1]),.addrb(ram_addresses[2][1]),.dib(ram_di[2][1]),.dob(ram_do[2][1])
);

tdp_bram bram4(
    .clka(ap_clk),.ena(ram_enables[3][0]),.wea(ram_write_enables[3][0]),.addra(ram_addresses[3][0]),.dia(ram_di[3][0]),.doa(ram_do[3][0]),
    .clkb(ap_clk),.enb(ram_enables[3][1]),.web(ram_write_enables[3][1]),.addrb(ram_addresses[3][1]),.dib(ram_di[3][1]),.dob(ram_do[3][1])
);

Packer packer(
        .ap_clk(ap_clk),
        .ap_rst_n(ap_rst_n),

        .valid_in(inData_tvalid_reg),
        .data_in(inData_tdata_reg),
        .last_in(inData_tlast_reg),   
        .tkeep(inData_tkeep_reg),

        .ram_write_enables(ram_write_enables),
        .ram_di(ram_di),
        .ram_addresses(ram_addresses)
    );








endmodule







module tdp_bram(
    input               clka,
    input               ena,
    input               wea,
    input       [9:0]   addra,
    input       [17:0]  dia,
    output reg  [17:0]  doa,

    input               clkb,
    input               enb,
    input               web,
    input       [9:0]   addrb,
    input       [17:0]  dib,
    output reg  [17:0]  dob
);

    // 1024 x 18-bit memory
    reg [17:0] ram [0:1023];

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
    input logic ap_clk,
    input logic ap_rst_n,
    output logic [15:0] E,
    output logic [15:0] Ko,
    output logic ke_done,
    output logic [8:0] Ko_word,
    output logic [3:0] Ko_segment,
    output logic [3:0] Ko_offset,
    
    output logic [10:0] dozen_count,
    output logic [3:0] colomn_end_count
);

assign ke_done =1;

/*
    
///////////////////////////////////  PARAMETER EXTRACTION BLOCK //////////////////////////////////////// START 
    logic [5:0] C;
    logic [18:0] TBS;
    logic Bg_No;
    logic [8:0] Z_c;
    logic [3:0] Qm;
    logic [2:0] V;
    logic [13:0] K_;
    logic [18:0] G;
    logic [5:0] Cr;
    logic [1:0] RV;
    
    always_comb begin
        
        C = cnData_tdata_reg[29:24];
        TBS = cnData_tdata_reg[18:0];
        Bg_No = cnData_tdata_reg[19:19];
        Z_c = cnData_tdata_reg[70:62];
        Qm = cnData_tdata_reg[23:20];
        V = cnData_tdata_reg[34:32];
        K_ = cnData_tdata_reg[87:74];
        G = cnData_tdata_reg[106:88];
        Cr = cnData_tdata_reg[122:117];
        RV = cnData_tdata_reg[31:30];
    end

    
///////////////////////////////////  PARAMETER EXTRACTION BLOCK ////////////////////////////////////////  END

    logic [14:0] N;
    logic [13:0] K;

    always_comb begin
        if (Bg_No == 1'b0) begin
            N = 66 * Z_c;
            K = 22 * Z_c;
        end else begin
            N = 50 * Z_c;
            K = 10 * Z_c;
        end
    end

    
    
    


    //////////////  NREF AND NCB CALCULATION  ///////

    logic [14:0] Nref;
    logic [14:0] Ncb;

    logic [20:0] mult;    
    logic [6:0]  denom;   
    logic [20:0] div_res;

    always_comb begin
        mult    = TBS * 3;
        denom   = C << 1;             // 2 * C
        div_res = mult / denom;       // truncates => floor
        Nref    = div_res[14:0];      // guaranteed to fit
        Ncb    = (N < Nref) ? N : Nref;
    end
    

    //////////////  Etemp CALUCULATION ////////////

    logic [21:0] Etemp;

    logic [5:0] Codeblock;

    logic [3:0] st1;
    logic [21:0] Etemp_buf;
    logic [9:0] denom2;

    always_comb begin 
        st1 = V*Qm;
        denom2 = st1 * C;
        Etemp_buf = (G / denom2) ;
        Etemp = Etemp_buf * st1;

        E =  Etemp;
    end
    
    
    /////////////  ko CALUCULATION //////////////

    logic [9:0] F;
    logic [15:0] K1;
    logic [15:0] K2;

    always_comb begin
        F = K - K_;
        
        if (Bg_No == 1'b0) begin
            case (RV)
                2'd0:    Ko = 0;
                2'd1:    Ko = ((17*Ncb)/N) * Z_c;
                2'd2:    Ko = ((33*Ncb)/N) * Z_c;
                default: Ko = ((56*Ncb)/N) * Z_c;

            endcase
        end else begin
            case (RV)
                2'd0:    Ko = 0;
                2'd1:    Ko = ((13*Ncb)/N) * Z_c;
                2'd2:    Ko = ((25*Ncb)/N) * Z_c;
                default: Ko = ((43*Ncb)/N) * Z_c;
            endcase
        end

        K1 = K  - Z_c*2;
        K2 = K_ - Z_c*2;

        if (Ko > K1) begin
            Ko = Ko - F;
        end else if ((Ko > K2) && (Ko <= K1) && (Ncb > K2) && (Ncb <= K1)) begin
            Ko = 0;
        end else if ((Ko > K2) && (Ko <= K1)) begin
            Ko = K2;
        end
        else Ko = Ko;
    end

*/

  assign Ko =0;
  assign E = 7200;
   logic [3:0] Qm = 2;

    always_comb begin
        Ko_word = Ko/128;
        Ko_segment = (Ko%128)/12;
        Ko_offset = (Ko%128)%12;
        dozen_count = (E/Qm)/12 ;
        colomn_end_count =  (E/Qm)%12;
    
    end



endmodule