module axi_lite_write_master (
    input  logic        clk,
    input  logic        reset_n,      // Active-low reset
    input  logic        start_write,  // Trigger signal from CPU/Master
    input  logic        awready,      // Slave ready for address
    input  logic        wready,       // Slave ready for data
    input  logic        bvalid,       // Slave response valid
    input  logic [1:0]  bresp,        // Response status (2'b00 = OKAY)
    
    output logic        awvalid,      // Master address valid
    output logic        wvalid,       // Master data valid
    output logic        bready,       // Master ready for response
    output logic [2:0]  current_state_dbg // For debugging/waveform inspection
);

    // Define states using an enumerated type (clean and readable)
    typedef enum logic [2:0] {
        S_IDLE    = 3'b000,
        S_AWVALID = 3'b001,
        S_WVALID  = 3'b010,
        S_BREADY  = 3'b011,
        S_ERROR   = 3'b100
    } state_t;

    state_t current_state, next_state;
    
    // Expose state to output port for easy waveform debugging
    assign current_state_dbg = current_state;

    //---------------------------------------------------------
    // 1. Sequential Block: State Register Update
    //---------------------------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    //---------------------------------------------------------
    // 2. Combinational Block: Next-State Logic
    //---------------------------------------------------------
    always_comb begin
        next_state = current_state; // Default is to stay in current state
        
        case (current_state)
            S_IDLE: begin
                if (start_write) begin
                    next_state = S_AWVALID;
                end
            end
            
            S_AWVALID: begin
                // Move to write data state once slave asserts awready
                if (awready) begin
                    next_state = S_WVALID;
                end
            end
            
            S_WVALID: begin
                // Move to response state once slave asserts wready
                if (wready) begin
                    next_state = S_BREADY;
                end
            end
            
            S_BREADY: begin
                // Wait for slave response valid signal
                if (bvalid) begin
                    if (bresp == 2'b00) begin 
                        next_state = S_IDLE; // Successful write complete
                    end else begin
                        next_state = S_ERROR; // Slave reported a bus error
                    end
                end
            end
            
            S_ERROR: begin
                // Stay locked in error state until system reset
                next_state = S_ERROR; 
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    //---------------------------------------------------------
    // 3. Combinational Block: Output Logic (Moore/Mealy)
    //---------------------------------------------------------
    always_comb begin
        // Default output values to prevent latches
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        
        case (current_state)
            S_AWVALID: awvalid = 1'b1;
            S_WVALID:  wvalid  = 1'b1;
            S_BREADY:  bready  = 1'b1;
            default: ; // All signals remain 0 in IDLE and ERROR
        endcase
    end

endmodule