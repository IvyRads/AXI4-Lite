`timescale 1ns / 1ps

// ============================================================
// Simple AXI4-Lite read slave model.
// Kept in its own module so its internal counters/flags do NOT
// show up at the top level of the testbench waveform.
// Returns CAFEBABE for address ABCD1234 and DEADBEEF for 00000040
// (the same values used in the write testbench).
// ============================================================
module axi_lite_read_slave_model (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        arvalid,
    output logic        arready,
    input  logic [31:0] araddr,
    output logic        rvalid,
    input  logic        rready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp
);

    // Delays in clock cycles (set by the testbench)
    int   ar_delay = 0, r_delay = 0;
    int   ar_cnt, r_cnt;
    logic ar_got;

    wire ar_hs = arvalid & arready;
    wire r_hs  = rvalid  & rready;

    assign rresp = 2'b00;   // always OKAY

    function automatic logic [31:0] lookup(input logic [31:0] a);
        case (a)
            32'hABCD_1234: lookup = 32'hCAFE_BABE;
            32'h0000_0040: lookup = 32'hDEAD_BEEF;
            default:       lookup = 32'h0000_0000;
        endcase
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            arready <= 0; rvalid <= 0; rdata <= 0;
            ar_got  <= 0; ar_cnt <= 0; r_cnt <= 0;
        end else begin
            arready <= 0;

            // Address channel: wait ar_delay cycles after VALID, then pulse READY
            if (arvalid && !arready && !ar_got) begin
                if (ar_cnt >= ar_delay) begin arready <= 1; ar_cnt <= 0; end
                else ar_cnt <= ar_cnt + 1;
            end
            if (ar_hs) begin
                ar_got <= 1;
                rdata  <= lookup(araddr);   // data is ready, held stable until accepted
            end

            // Data channel: only after the address was accepted
            if (ar_got && !rvalid) begin
                if (r_cnt >= r_delay) begin rvalid <= 1; r_cnt <= 0; end
                else r_cnt <= r_cnt + 1;
            end
            if (r_hs) begin
                rvalid <= 0;
                ar_got <= 0;
            end
        end
    end

endmodule


// ============================================================
// Testbench top: only the primary AXI signals are declared here,
// so the waveform opens with just the signals you want to show.
// ============================================================
module tb_axi_lite_read_master;

    logic        clk = 0;
    logic        reset_n;
    logic        start;
    logic [31:0] addr_in;
    logic [31:0] read_data;
    logic        done;

    // Read address channel
    logic        arvalid;
    logic        arready;
    logic [31:0] araddr;

    // Read data channel
    logic        rvalid;
    logic        rready;
    logic [31:0] rdata;
    logic [1:0]  rresp;

    always #5 clk = ~clk;   // 100 MHz

    axi_lite_read_master dut (
        .clk      (clk),
        .reset_n  (reset_n),
        .start    (start),
        .addr_in  (addr_in),
        .data_out (read_data),
        .done     (done),
        .error    (),            // unused, kept off the waveform
        .arvalid  (arvalid),
        .arready  (arready),
        .araddr   (araddr),
        .rvalid   (rvalid),
        .rready   (rready),
        .rdata    (rdata),
        .rresp    (rresp)
    );

    axi_lite_read_slave_model slave (
        .clk      (clk),
        .reset_n  (reset_n),
        .arvalid  (arvalid),
        .arready  (arready),
        .araddr   (araddr),
        .rvalid   (rvalid),
        .rready   (rready),
        .rdata    (rdata),
        .rresp    (rresp)
    );

    // One full read + self-check
    task do_read(input [31:0] a, input [31:0] expected);
        begin
            @(posedge clk);
            addr_in <= a;
            start   <= 1;
            @(posedge clk);
            start   <= 0;
            wait (done);
            @(posedge clk);
            if (read_data === expected && !dut.error)
                $display("[%0t] PASS: addr=%h read=%h", $time, a, read_data);
            else
                $display("[%0t] FAIL: addr=%h read=%h expected=%h", $time, a, read_data, expected);
        end
    endtask

    initial begin
        reset_n = 0; start = 0; addr_in = 0;
        #22 reset_n = 1;
        #20;

        // Test 1: SLOW slave -> arvalid stays high waiting for arready,
        //                       rready stays high waiting for rvalid
        slave.ar_delay = 3; slave.r_delay = 5;
        do_read(32'hABCD_1234, 32'hCAFE_BABE);

        #40;

        // Test 2: FAST slave -> handshakes complete right away
        slave.ar_delay = 0; slave.r_delay = 0;
        do_read(32'h0000_0040, 32'hDEAD_BEEF);

        #50;
        $finish;
    end

endmodule