`timescale 1ns / 1ps

// ============================================================
// Simple AXI4-Lite slave model.
// Kept in its own module so its internal counters/flags do NOT
// show up at the top level of the testbench waveform.
// ============================================================
module axi_lite_slave_model (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] awaddr,
    input  logic        wvalid,
    output logic        wready,
    input  logic [31:0] wdata,
    output logic        bvalid,
    input  logic        bready,
    output logic [1:0]  bresp
);

    // Delays in clock cycles (set by the testbench)
    int          aw_delay = 0, w_delay = 0, b_delay = 0;
    int          aw_cnt, w_cnt, b_cnt;
    logic        aw_got, w_got;
    logic [31:0] slave_addr, slave_data;

    wire aw_hs = awvalid & awready;
    wire w_hs  = wvalid  & wready;
    wire b_hs  = bvalid  & bready;

    assign bresp = 2'b00;   // always OKAY

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            awready <= 0; wready <= 0; bvalid <= 0;
            aw_got  <= 0; w_got  <= 0;
            aw_cnt  <= 0; w_cnt  <= 0; b_cnt <= 0;
        end else begin
            awready <= 0;
            wready  <= 0;

            // Address channel
            if (awvalid && !awready && !aw_got) begin
                if (aw_cnt >= aw_delay) begin awready <= 1; aw_cnt <= 0; end
                else aw_cnt <= aw_cnt + 1;
            end
            if (aw_hs) begin aw_got <= 1; slave_addr <= awaddr; end

            // Data channel
            if (wvalid && !wready && !w_got) begin
                if (w_cnt >= w_delay) begin wready <= 1; w_cnt <= 0; end
                else w_cnt <= w_cnt + 1;
            end
            if (w_hs) begin w_got <= 1; slave_data <= wdata; end

            // Response: only after BOTH address and data were accepted
            if (aw_got && w_got && !bvalid) begin
                if (b_cnt >= b_delay) begin bvalid <= 1; b_cnt <= 0; end
                else b_cnt <= b_cnt + 1;
            end
            if (b_hs) begin
                bvalid <= 0;
                aw_got <= 0;
                w_got  <= 0;
            end
        end
    end

endmodule


// ============================================================
// Testbench top: only the primary AXI signals are declared here,
// so the waveform opens with just the signals you want to show.
// ============================================================
module tb_axi_lite_write_master;

    logic        clk = 0;
    logic        reset_n;
    logic        start;
    logic [31:0] addr_in;
    logic [31:0] data_in;
    logic        done;

    // Write address channel
    logic        awvalid;
    logic        awready;
    logic [31:0] awaddr;

    // Write data channel
    logic        wvalid;
    logic        wready;
    logic [31:0] wdata;

    // Write response channel
    logic        bvalid;
    logic        bready;
    logic [1:0]  bresp;

    always #5 clk = ~clk;   // 100 MHz

    axi_lite_write_master dut (
        .clk     (clk),
        .reset_n (reset_n),
        .start   (start),
        .addr_in (addr_in),
        .data_in (data_in),
        .done    (done),
        .error   (),            // unused, kept off the waveform
        .awvalid (awvalid),
        .awready (awready),
        .awaddr  (awaddr),
        .wvalid  (wvalid),
        .wready  (wready),
        .wdata   (wdata),
        .wstrb   (),            // unused, kept off the waveform
        .bvalid  (bvalid),
        .bready  (bready),
        .bresp   (bresp)
    );

    axi_lite_slave_model slave (
        .clk     (clk),
        .reset_n (reset_n),
        .awvalid (awvalid),
        .awready (awready),
        .awaddr  (awaddr),
        .wvalid  (wvalid),
        .wready  (wready),
        .wdata   (wdata),
        .bvalid  (bvalid),
        .bready  (bready),
        .bresp   (bresp)
    );

    // One full write + self-check
    task do_write(input [31:0] a, input [31:0] d);
        begin
            @(posedge clk);
            addr_in <= a;
            data_in <= d;
            start   <= 1;
            @(posedge clk);
            start   <= 0;
            wait (done);
            @(posedge clk);
            if (slave.slave_addr === a && slave.slave_data === d && !dut.error)
                $display("[%0t] PASS: addr=%h data=%h", $time, slave.slave_addr, slave.slave_data);
            else
                $display("[%0t] FAIL: got addr=%h data=%h", $time, slave.slave_addr, slave.slave_data);
        end
    endtask

    initial begin
        reset_n = 0; start = 0; addr_in = 0; data_in = 0;
        #22 reset_n = 1;
        #20;

        // Test 1: SLOW slave -> VALID stays high while waiting for READY
        slave.aw_delay = 3; slave.w_delay = 6; slave.b_delay = 3;
        do_write(32'hABCD_1234, 32'hCAFE_BABE);

        #40;

        // Test 2: FAST slave -> READY comes right away
        slave.aw_delay = 0; slave.w_delay = 0; slave.b_delay = 0;
        do_write(32'h0000_0040, 32'hDEAD_BEEF);

        #50;
        $finish;
    end

endmodule