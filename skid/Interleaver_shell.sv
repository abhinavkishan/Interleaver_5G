

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
    




logic [127:0] pData_tdata;
logic pData_tvalid;
logic pData_tlast;

logic PACKER_trigger;

logic [15:0] N;
logic N_valid;
logic N_ready;

Packer packer(
    .ap_clk(ap_clk),                              // input wire ap_clk
    .ap_rst_n(ap_rst_n),

    .inData_tdata(inData_tdata),
    .inData_tready(inData_tready),
    .inData_tvalid(inData_tvalid),
    .inData_tlast(inData_tlast),
    .inData_tkeep(inData_tkeep),

    .pData_tdata(pData_tdata),
    .pData_tvalid(pData_tvalid),
    .pData_tlast(pData_tlast),
    
    .trigger(PACKER_trigger),

    .N(N),
    .N_valid(N_valid),
    .N_ready(N_ready)
);




logic [66:0] KEC_out_tdata;
logic KEC_out_tready;
logic KEC_out_tvalid;



KEC_0 KEC (
  .ap_clk(ap_clk),                              // input wire ap_clk
  .ap_rst_n(ap_rst_n),                          // input wire ap_rst_n

  .config_stream_TDATA(cnData_tdata),    // input wire [127 : 0] config_stream_TDATA
  .config_stream_TREADY(cnData_tready),  // output wire config_stream_TREADY
  .config_stream_TVALID(cnData_tvalid),  // input wire config_stream_TVALID

  .out_stream_TDATA(KEC_out_tdata),          // output wire [66 : 0] out_stream_TDATA
  .out_stream_TREADY(KEC_out_tready),        // input wire out_stream_TREADY
  .out_stream_TVALID(KEC_out_tvalid)        // output wire out_stream_TVALID
);

wire [14:0] BPR = KEC_out_tdata[66:52];
wire [15:0] E = KEC_out_tdata[51:36];
wire [15:0] Ko = KEC_out_tdata[35:20];
wire [5:0] C= KEC_out_tdata[19:14];
wire [5:0] Cr = KEC_out_tdata[13:8];
wire [3:0] Q = KEC_out_tdata[7:4];
wire [3:0] V = KEC_out_tdata[3:0];




logic [35:0] ImConfig_tdata;
logic ImConfig_tvalid;
logic ImConfig_tready;

logic [15:0] pointer_tdata;
logic pointer_tvalid;

logic [1:0] IM_frame[0:1];
logic [9:0] IM_address[0:1];
logic [47:0] IM_data[0:1];

logic IM_done;


logic out_ready_control;



control  Control(

    .ap_clk(ap_clk),                              // input wire ap_clk
    .ap_rst_n(ap_rst_n),

    .N_ext(N),
    .N_ext_valid(N_valid),
    .N_ext_ready(N_ready),

    .pData_tdata(pData_tdata),
    .pData_tvalid(pData_tvalid),
    .pData_tlast(pData_tlast),

    .PACKER_trigger(PACKER_trigger),


   //////// CONFIG INFO ///////////////

    .BPR_ext(BPR),
    .E_ext(E),
    .Ko_ext(Ko),
    .Q_ext(Q),
    .V_ext(V),
    .C_ext(C),
    .Cr_ext(Cr),


    .KEC_tvalid(KEC_out_tvalid),
    .KEC_tready(KEC_out_tready),



    .ImConfig_tdata(ImConfig_tdata),
    .ImConfig_tvalid(ImConfig_tvalid),
    .ImConfig_tready(ImConfig_tready),
    .out_ready_control(out_ready_control),

    .Pointer_tdata(pointer_tdata),
    .Pointer_tvalid(pointer_tvalid),



    .IM_frame(IM_frame),
    .IM_address(IM_address),
    .IM_data(IM_data),
    .IM_done(IM_done)
);


Interleaver_Memory IM(
    .ImConfig_tdata(ImConfig_tdata),
    .ImConfig_tvalid(ImConfig_tvalid),
    .ImConfig_tready(ImConfig_tready),

    .pointer_tdata(pointer_tdata),
    .pointer_tvalid(pointer_tvalid),



    .IM_frame(IM_frame),
    .IM_address(IM_address),
    .IM_data(IM_data),

    


    .outData_tdata(outData_tdata),
    .outData_tlast(outData_tlast),
    .outData_tvalid(outData_tvalid),
    .outData_tready_actual(outData_tready),



    .out_ready_control(out_ready_control),

    .ap_clk(ap_clk),                              // input wire ap_clk
    .ap_rst_n(ap_rst_n),

    .IM_done(IM_done)
);

endmodule
