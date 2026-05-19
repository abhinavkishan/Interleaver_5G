`timescale 1ns / 1ps





module design_1_wrapper_tb();

reg [127:0]tdata_in;
reg tvalid_in;
wire tready_in;
reg [6:0]tkeep_in;
reg [0:0]tlast_in;


reg [127:0]tdata_in_config;                    //Interleaver
reg tvalid_in_config;
wire tready_in_config;


wire tvalid_out;
reg tready_out;
wire [95:0]tdata_out;
wire [0:0]tlast_out;




reg clk =0;
reg rst =0;

always #5 clk<=~clk;

initial begin
rst =0;
#5000 $finish;
end

integer i,j,k,l;
reg [95:0] err_tdata_out;
integer err_count_tdata_out;





reg [127:0] in_data  [80000:0];
reg [0:0] in_last  [80000:0];
reg [6:0] in_keep  [80000:0];
reg [95:0] out_data [80000:0];
reg [127:0] config_data [0:0];

    initial $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_filler_out",in_data);
    initial $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_last",in_last);
    initial $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_keep",in_keep);
    initial $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_Interleaver_out",out_data);
    initial $readmemh("/home/thrinath/Documents/interleaver/Interleaver_test_vectors_IDE/test_case_15_config",config_data);
    

 Interleaver_shell Interleaver
    (   .cnData_tdata(tdata_in_config),
        .cnData_tready(tready_in_config),
        .cnData_tvalid(tvalid_in_config),

        .inData_tdata(tdata_in),
        .inData_tkeep(tkeep_in),
        .inData_tvalid(tvalid_in),
        .inData_tready(tready_in),
        .inData_tlast(tlast_in),

        .outData_tdata(tdata_out),
        .outData_tlast(tlast_out),
        .outData_tvalid(tvalid_out),
        .outData_tready(tready_out),

        .ap_rst_n(rst),
        .ap_clk(clk));

initial begin


    tdata_in = in_data[0];
    tvalid_in = 1'b1;
    tlast_in = in_last[0];
    tkeep_in = in_keep[0];
    
    
    tdata_in_config = config_data[0];    //Interleaver
    tvalid_in_config = 1'b1;
    
    tready_out = 1'b1;

    i=0; j=0;  k=0; l=0;
      
    err_count_tdata_out=0;
    err_tdata_out = 0;
          

end

reg [4:0] reset_counter=0;

always@(posedge clk)begin
    reset_counter <= reset_counter +1;
    if(reset_counter==10) rst <=1;
end

always@(posedge clk) begin      
    if (tready_in==1'b1 && tvalid_in==1'b1) begin
        #5
        i=(i+1);              
        tdata_in=in_data[i];
        tkeep_in=in_keep[i];
        tlast_in=in_last[i];
        end
    end
    

always@(posedge clk) begin  
    if (tvalid_out==1'b1 && tready_out==1'b1) begin                     
        err_tdata_out = out_data[j]^tdata_out;   
        j=j+1;                                                                       
        if (err_tdata_out>0) err_count_tdata_out = err_count_tdata_out+1;
    end
end
endmodule



    /*
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_filler_out",in_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_last",in_last);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_keep",in_keep);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_Interleaver_out",out_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_config",config_data);
    



    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_filler_out",in_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_last",in_last);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_keep",in_keep);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_Interleaver_out",out_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_config",config_data);
    

    reg clk =0;
    reg rst =0;

    always #10 clk<=~clk;
    
    initial begin
    rst =0;
        #2500 $finish;
    
    end


    

    */