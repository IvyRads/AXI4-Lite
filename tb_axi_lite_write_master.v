`timescale 1ns / 1ps

module tb_axi_lite_write_master;

    // Testbench signals
    logic        clk;
    logic        reset_n;
    logic        start_write;
    logic        awready;
    logic        wready;
    logic        bvalid;
    logic [1:0]  bresp;
    
    logic        awvalid;
    logic        wvalid;
    logic        bready;
    logic [2:0]  current_state_dbg;

    // Instantiate the Unit Under Test (UUT)
    axi_lite_write_master uut (
        .clk(clk),
        .reset_n(reset_n),
        .start_write(start_write),
        .awready(awready),
        .wready(wready),
        .bvalid(bvalid),
        .bresp(bresp),
        .awvalid(awvalid),
        .wvalid(wvalid),
        .bready(bready),
        .current_state_dbg(current_state_dbg)
    );

    // 1. Clock Generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // 2. Stimulus Process
    initial begin
        // Initialize all inputs
        clk         = 0;
        reset_n     = 0;
        start_write = 0;
        awready     = 0;
        wready      = 0;
        bvalid      = 0;
        bresp       = 2'b00; // OKAY response

        // Hold reset for 20ns
        #20;
        reset_n = 1;
        #15;

        // --- TEST CASE 1: Standard Successful Write Transaction ---
        $display("[%0t ns] Starting Write Transaction...", $time);
        start_write = 1;
        #10;
        start_write = 0; // Pulse start_write for 1 clock cycle

        // Wait a couple of cycles, then assert slave address ready (awready)
        @(posedge clk);
        #2;
        awready = 1;
        
        // Wait for FSM to enter WVALID state, then assert data ready (wready)
        @(posedge clk);
        #2;
        awready = 0; // Turn off address ready
        wready  = 1;  // Slave is ready for data

        // Wait for FSM to enter BREADY state, then send response valid (bvalid)
        @(posedge clk);
        #2;
        wready  = 0;  // Turn off data ready
        bvalid  = 1;  // Slave says response is ready
        bresp   = 2'b00; // Success (OKAY)

        // Wait for master's bready handshake completion
        @(posedge clk);
        #2;
        bvalid  = 0;  // Clear response valid

        #30;
        $display("[%0t ns] Testbench completed successfully!", $time);
        $finish;
    end

    // Monitor state transitions in the simulator console
    initial begin
        $monitor("Time=%0t | State=%b | awvalid=%b | wvalid=%b | bready=%b | awready=%b | wready=%b | bvalid=%b",
                 $time, current_state_dbg, awvalid, wvalid, bready, awready, wready, bvalid);
    end

endmodule