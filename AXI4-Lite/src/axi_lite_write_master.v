// Simple AXI4-Lite write master (32-bit address and data)
// Handshake rule: a transfer happens on the clock edge where VALID && READY are both 1.
// Master rule: once VALID is raised, hold it (and the payload) until READY is seen.
module axi_lite_write_master (
    input  logic        clk,
    input  logic        reset_n,      // Active-low reset

    // User side
    input  logic        start,        // 1-cycle pulse to begin a write
    input  logic [31:0] addr_in,
    input  logic [31:0] data_in,
    output logic        done,         // 1-cycle pulse when write completes
    output logic        error,        // 1 if bresp != OKAY

    // AXI write address channel
    output logic        awvalid,
    input  logic        awready,
    output logic [31:0] awaddr,

    // AXI write data channel
    output logic        wvalid,
    input  logic        wready,
    output logic [31:0] wdata,
    output logic [3:0]  wstrb,

    // AXI write response channel
    input  logic        bvalid,
    output logic        bready,
    input  logic [1:0]  bresp
);

    typedef enum logic [1:0] {IDLE, WRITE, RESP} state_t;
    state_t state;

    assign wstrb = 4'hF;   // write all 4 bytes

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state   <= IDLE;
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
            bready  <= 1'b0;
            awaddr  <= 32'h0;
            wdata   <= 32'h0;
            done    <= 1'b0;
            error   <= 1'b0;
        end else begin
            done <= 1'b0;                       // default: done is a 1-cycle pulse

            case (state)
                // Wait for start, then raise AW and W valid together
                IDLE: begin
                    if (start) begin
                        awaddr  <= addr_in;
                        wdata   <= data_in;
                        awvalid <= 1'b1;
                        wvalid  <= 1'b1;
                        error   <= 1'b0;
                        state   <= WRITE;
                    end
                end

                // Hold VALID until the matching READY arrives (each channel independent)
                WRITE: begin
                    if (awvalid && awready) awvalid <= 1'b0;
                    if (wvalid  && wready ) wvalid  <= 1'b0;

                    // Both channels finished (or finishing this cycle)
                    if ((!awvalid || awready) && (!wvalid || wready)) begin
                        bready <= 1'b1;
                        state  <= RESP;
                    end
                end

                // Accept the slave's write response
                RESP: begin
                    if (bvalid && bready) begin
                        bready <= 1'b0;
                        error  <= (bresp != 2'b00);
                        done   <= 1'b1;
                        state  <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule