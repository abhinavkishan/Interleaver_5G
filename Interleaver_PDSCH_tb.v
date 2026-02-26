`timescale 1ns / 1ps



module design_1_wrapper_tb();

    reg [127:0]tdata_in;
    reg tvalid_in;
    wire tready_in;
    reg [6:0]tkeep_in;
    reg [0:0]tlast_in;


    reg [127:0]tdata_int_config;                    //Interleaver
    reg tvalid_int_config;
    wire tready_int_config;


    wire tvalid_out;
    reg tready_out;
    wire [95:0]tdata_out;
    wire [0:0]tlast_out;

    reg clk =0;
    reg rst =0;

    always #10 clk<=~clk;
    
    initial begin
    rst =0;
        #1000 $finish;
    
    end

    integer i,j,k,l;
    reg [95:0] err_tdata_out;
    integer err_count_tdata_out;


    //reg [31:0] data;
    integer in_count, out_count;


    reg [127:0] in_data  [8000:0];
    reg [0:0] in_last  [8000:0];
    reg [6:0] in_keep  [8000:0];
    reg [95:0] out_data [8000:0];
    reg [127:0] config_data [0:0];


    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_filler_out",in_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_last",in_last);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_keep",in_keep);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_Interleaver_out",out_data);
    initial $readmemh("/home/thrinath/Documents/Interleaver/Interleaver_test_vectors_IDE/test_case_3_config",config_data);



    Interleaver_shell Interleaver
    (   .cnData_tdata(tdata_int_config),
        .cnData_tready(tready_int_config),
        .cnData_tvalid(tvalid_int_config),

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
        in_count = 0;
        out_count = 0;



        in_count = in_data[0][31:0];
        out_count = out_data[0][31:0];



        $display(in_count);      //last is 3(burst of data)
        $display(out_count);     //last is 1(burst of data)


        tdata_in = in_data[0];
        tvalid_in = 1'b1;
        tlast_in = in_last[0];
        tkeep_in = in_keep[0];
        
        
        tdata_int_config = config_data[0];    //Interleaver
        tvalid_int_config = 1'b1;
        
        tready_out = 1'b1;

        i=1;  j=1; k=0;l=0;
        
        err_count_tdata_out=0;
        err_tdata_out = 0;
            

    end

    always@(posedge clk) begin     
    
        rst <=1;                   //Input data
        if (tready_in==1'b1 && tvalid_in==1'b1) begin
            #5
            i=(i+1);
            if(i==in_count) tlast_in = 1'b1;          //in_count=3
            else tlast_in = 1'b0;
            
            if(i==in_count+1) i=1;                    //in_count=4
            tdata_in=in_data[i];
            end
        end
        
    always@(posedge clk) begin                        //last data
        if (tready_in==1'b1 && tvalid_in==1'b1) begin
            #5
        k=(k+1);
            if(k==in_count) k=0;                    //in_count=4
            tlast_in=in_last[k];
            end
        end

    always@(posedge clk) begin                        //keep data
        if (tready_in==1'b1 && tvalid_in==1'b1) begin
            #5
        l=(l+1);
            if(l==in_count) l=0;                    //in_count=4
            tkeep_in=in_keep[l];
            end
        end

    always@(posedge clk) begin  
        if (tvalid_out==1'b1 && tready_out==1'b1) begin                     
            err_tdata_out = out_data[j]^tdata_out;   
            j=j+1;                                                           
            if (j==out_count+1) j=1;                
            if (err_tdata_out>0) err_count_tdata_out = err_count_tdata_out+1;
        end
    end
endmodule
