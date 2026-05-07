

module Packer(
    input  logic ap_clk,
    input  logic ap_rst_n,

    input  logic [127:0] inData_tdata,
    output logic inData_tready,
    input  logic inData_tvalid,
    input  logic inData_tlast,
    input  logic [6:0] inData_tkeep,

    output  logic [127:0] outData_tdata,
    output  logic outData_tvalid,
    output  logic outData_tlast,




    input logic run,
    output logic done,
    output logic [15:0] N
);

   


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
    
      


    logic [127:0] buffer;    
    logic [6:0]   free;     
    logic         spill;

    

    always_comb begin
        spill   = 1'b0;
        if(last_in_modified_reg[0] && !last_in_modified_reg[1]) begin
            if(free==7'd127) spill = 0;
            else spill =1;
        end

        else if (valid_in && !last_in_modified_reg[1]) begin
            if (free>tkeep_modified)  spill   = 1'b0;
            else spill   = 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------


   
    always_ff @(posedge ap_clk ) begin
        if (!ap_rst_n) begin
            buf0     <= '0;
            free     <= 127;
        end 
        else begin
            if (valid_in && !last_in_modified_reg[0] ) begin

                if (spill)  begin
                    buf0 <= data_in_modified;
                    free <=127 + free-tkeep_modified;
                end    
                else begin
                    buf0 <= (buf0<<(tkeep_modified+1)) | data_in_modified;
                    free <= free -tkeep_modified -1;
                end    

            end
        end
    end
    
    
    always@(posedge ap_clk) begin
    
        if(!ap_rst_n) N<=0;
        else if(!last_in_modified_reg[0] && valid_in) N <=  N+tkeep_modified+1;
    
    end


 always @(posedge ap_clk) begin
        if (ram_write_enable) begin
            $fwrite(fd, "%032h\n", ram_write_data);

            $display("write happening");
        end
    end
    
    final begin
        $fclose(fd);
    end
    
    assign packing_done = last_in_modified_reg[1];
    assign ram_write_enable = spill;
    wire [127:0] ram_write_data= (buf0<<(free+1)) | (data_in_modified>>(tkeep_modified-free));


    

endmodule


module Packer (
    input  logic         ap_clk,
    input  logic         ap_rst_n,

    // AXI-S Slave (input)
    input  logic [127:0] inData_tdata,
    output logic         inData_tready,
    input  logic         inData_tvalid,
    input  logic         inData_tlast,
    input  logic [6:0]   inData_tkeep,   // tkeep+1 = number of valid bits; bits[tkeep:0] valid

    // AXI-S Master (output) — no tready on output
    output logic [127:0] outData_tdata,
    output logic         outData_tvalid,
    output logic         outData_tlast,

    // Control
    input  logic         run,            // single-cycle trigger to (re)start
    output logic [15:0]  N               // total packed bits written
);

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE    = 2'd0,
        RUNNING = 2'd1,
        FLUSH   = 2'd2,   // last word received, drain leftover bits
        DONE    = 2'd3
    } state_t;

    state_t state;

    // Internal buffer and fill pointer
    // fill: index of the MSB of used region.
    //   fill == 127 => buffer fully empty (all 128 bits free)
    //   fill ==   0 => buffer has 128 bits used (full)
    logic [127:0] buf0;
    logic [6:0]   fill;       // counts down: 127 = empty, 0 = full

    // Pipeline register for inData_tlast (one-cycle delay to match old code)
    logic last_d1;

    // Number of valid input bits this cycle
    logic [6:0] valid_bits;   // = tkeep + 1

    // Combinational shift results
    logic [127:0] data_lo;    // portion that stays in current output word
    logic [127:0] data_hi;    // leftover bits that go into next buffer
    logic         spill;      // 1 = we have a full 128-bit word to output

    // -----------------------------------------------------------------------
    // ready: accept input only when RUNNING and not the cycle we register last
    // -----------------------------------------------------------------------
    assign inData_tready = (state == RUNNING);

    // Qualified input handshake
    wire xfer = inData_tvalid && inData_tready;

    // -----------------------------------------------------------------------
    // valid_bits
    // -----------------------------------------------------------------------
    always_comb valid_bits = inData_tkeep + 7'd1;

    // -----------------------------------------------------------------------
    // Combinational: shift logic
    //
    // fill = number of free bits - 1  (127 means all 128 bits free)
    // We want to place valid_bits new bits just below the already-used region.
    //
    // Conceptually the buffer grows from MSB downward:
    //   buf0[127 : 127-used+1]  = packed data so far
    //   buf0[fill : 0]          = free
    //
    // Input bits[tkeep:0] are the valid bits (LSB-justified in inData_tdata).
    // We need to left-shift them by (127 - tkeep) to bring them to MSB.
    // Then right-shift by (127 - fill) to align them below the used region,
    // which is equivalent to shifting left by (fill - tkeep).
    //
    // Cases:
    //   fill >= tkeep  => all valid bits fit without spill
    //                     data_lo = data_msb >> (fill - tkeep)   [right-align to free region]
    //                     Actually: left-shift input by (fill - tkeep) so MSBs land at bit `fill`
    //   fill < tkeep   => input overflows, generate spill
    //                     data_lo = data_msb >> (tkeep - fill)   [fills remaining free bits]
    //                     data_hi = data_msb << (128 + fill - tkeep)  [overflow to next buffer]
    //
    // Where data_msb = inData_tdata << (127 - tkeep)  (bring valid bits to MSB)
    // -----------------------------------------------------------------------
    logic [127:0] data_msb;

    always_comb begin
        data_msb = inData_tdata << (7'd127 - inData_tkeep);  // left-justify valid bits
        data_lo  = '0;
        data_hi  = '0;
        spill    = 1'b0;

        if (xfer) begin
            if (fill >= inData_tkeep) begin
                // No spill: shift MSB-justified input right to fit below used region
                data_lo = data_msb >> (fill - inData_tkeep);
                spill   = 1'b0;
            end else begin
                // Spill: lower bits fill the buffer, upper bits go to next buffer
                data_lo = data_msb >> (inData_tkeep - fill);   // fills buffer to bit 0
                data_hi = data_msb << (7'd128 + fill - inData_tkeep); // overflow portion
                spill   = 1'b1;
            end
        end else if (state == FLUSH) begin
            // No new input, just flush leftover buffer
            // spill only if there are real bits in buffer (fill != 127)
            spill = (fill != 7'd127);
        end
    end

    // -----------------------------------------------------------------------
    // Output data
    // -----------------------------------------------------------------------
    always_comb begin
        outData_tdata  = buf0 | data_lo;
        outData_tvalid = spill;
        outData_tlast  = (state == FLUSH) && spill;
    end

    // -----------------------------------------------------------------------
    // Sequential logic
    // -----------------------------------------------------------------------
    always_ff @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            state  <= IDLE;
            buf0   <= '0;
            fill   <= 7'd127;
            last_d1<= 1'b0;
            N      <= 16'd0;
        end else begin
            last_d1 <= (xfer) ? inData_tlast : 1'b0;

            case (state)

                IDLE: begin
                    if (run) begin
                        state <= RUNNING;
                        buf0  <= '0;
                        fill  <= 7'd127;
                        N     <= 16'd0;
                    end
                end

                RUNNING: begin
                    if (xfer) begin
                        if (spill) begin
                            // Write current word, load overflow into buffer
                            buf0 <= data_hi;
                            fill <= 7'd127 + fill - inData_tkeep;  // new fill after spill
                            N    <= N + 16'd128;
                        end else begin
                            // Accumulate into buffer
                            buf0 <= buf0 | data_lo;
                            fill <= fill - valid_bits;
                        end

                        if (inData_tlast) begin
                            // Stop accepting input; move to FLUSH
                            state <= FLUSH;
                        end
                    end
                end

                FLUSH: begin
                    // Output leftover bits (if any) in buf0
                    if (fill != 7'd127) begin
                        // One cycle flush
                        N     <= N + (7'd127 - fill);
                        buf0  <= '0;
                        fill  <= 7'd127;
                        state <= DONE;
                    end else begin
                        // Buffer was empty when last arrived
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Stay here until run re-triggers
                    if (run) begin
                        state <= RUNNING;
                        buf0  <= '0;
                        fill  <= 7'd127;
                        N     <= 16'd0;
                    end
                end

            endcase
        end
    end

endmodule
