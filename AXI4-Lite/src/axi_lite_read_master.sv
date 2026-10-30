// Simple AXI4-Lite read master (32-bit address and data)
// Handshake rule: a transfer happens on the clock edge where VALID && READY are both 1.
//   AR channel: master sends the address   (arvalid/arready)
//   R  channel: slave returns data + status (rvalid/rready)
module axi_lite_read_master (
    input  logic        clk,
    input  logic        reset_n,      // Active-low reset

    // User side
    input  logic        start,        // 1-cycle pulse to begin a read
    input  logic [31:0] addr_in,
    output logic [31:0] data_out,     // data returned by the slave
    output logic        done,         // 1-cycle pulse when read completes
    output logic        error,        // 1 if rresp != OKAY

    // AXI read address channel
    output logic        arvalid,
    input  logic        arready,
    output logic [31:0] araddr,

    // AXI read data channel
    input  logic        rvalid,
    output logic        rready,
    input  logic [31:0] rdata,
    input  logic [1:0]  rresp
);

    typedef enum logic [1:0] {IDLE, ADDR, DATA} state_t;
    state_t state;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state    <= IDLE;
            arvalid  <= 1'b0;
            rready   <= 1'b0;
            araddr   <= 32'h0;
            data_out <= 32'h0;
            done     <= 1'b0;
            error    <= 1'b0;
        end else begin
            done <= 1'b0;                       // default: done is a 1-cycle pulse

            case (state)
                // Wait for start, then raise arvalid with the address
                IDLE: begin
                    if (start) begin
                        araddr  <= addr_in;
                        arvalid <= 1'b1;
                        error   <= 1'b0;
                        state   <= ADDR;
                    end
                end

                // Hold arvalid until the slave accepts the address
                ADDR: begin
                    if (arvalid && arready) begin
                        arvalid <= 1'b0;
                        rready  <= 1'b1;
                        state   <= DATA;
                    end
                end

                // Accept the read data when the slave presents it
                DATA: begin
                    if (rvalid && rready) begin
                        rready   <= 1'b0;
                        data_out <= rdata;
                        error    <= (rresp != 2'b00);
                        done     <= 1'b1;
                        state    <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule