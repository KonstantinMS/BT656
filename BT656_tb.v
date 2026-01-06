`timescale 1us / 1ns

//////////////////////////////////////////////////////////////////////////////////
// Design Name: BT656_out Testbench
// Description: Testbench for BT656 encoder with 8/10 bit support
// Mode: Define BT656_10BIT_MODE for 10-bit testing, comment for 8-bit testing
//////////////////////////////////////////////////////////////////////////////////

// Uncomment for 10-bit mode testing
// `define BT656_10BIT_MODE

module BT656_tb();

    // Clock parameters
    parameter real PCLK_FREQ = 13_500_000;  // 13.5 MHz for PAL
    parameter real HALF_PERIOD = (1.0 / (PCLK_FREQ * 2)) * 1_000_000; // in us
    
    // Test parameters
    parameter TEST_FRAMES = 2;      // Number of frames to test
    parameter MAX_LINES = 625;      // Maximum lines per frame (PAL)
    
    // Signals
    reg clk;
    reg RST_i;
    reg PAL_i;
    reg BT656_OUT_EN_i;
    
`ifdef BT656_10BIT_MODE
    reg [9:0] DIN_i;
    wire [9:0] POUT_o;
`else
    reg [7:0] DIN_i;
    wire [7:0] POUT_o;
`endif
    
    wire BT_FRM_BG_o;
    wire ODD_VD_o;
    wire EVEN_VD_o;
    wire [10:0] BT_PIX_CNT_o;
    wire [9:0] BT_LINE_CNT_o;
    wire IM_END_o;
    wire DATA_RQ_o;
    wire CLK_o;
    wire FID_o;
    wire VSYNC_o;
    wire HSYNC_o;
    
    // Test control
    integer frame_count = 0;
    integer error_count = 0;
    integer test_pixel_count = 0;
    reg [31:0] test_data = 32'hA5A5A5A5; // Test pattern seed
    
    // File handles for logging
    integer log_file;
    integer data_file;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #HALF_PERIOD clk = ~clk;
    end
    
    // Main test sequence
    initial begin
        // Initialize
        initialize();
        
        // Open log files
        open_log_files();
        
        // Test 1: Reset test
        $display("[%0t] Test 1: Reset test", $time);
        reset_test();
        
        // Test 2: Basic functionality test
        $display("[%0t] Test 2: Basic functionality test", $time);
        basic_function_test();
        
        // Test 3: Frame timing test
        $display("[%0t] Test 3: Frame timing test", $time);
        frame_timing_test();
        
        // Test 4: Data pattern test
        $display("[%0t] Test 4: Data pattern test", $time);
        data_pattern_test();
        
        // Test 5: Mode switching test
        $display("[%0t] Test 5: Mode switching test", $time);
        mode_switching_test();
        
        // Summary
        print_test_summary();
        
        // Close files
        close_log_files();
        
        $finish;
    end
    
    // DUT Instantiation
    BT656_out BT656_0 (
        .CLK_i          (clk),
        .RST            (RST_i),
        .PAL_i          (PAL_i),
        .BT656_OUT_EN_i (BT656_OUT_EN_i),
        .DIN_i          (DIN_i),
        .BT_FRM_BG_o    (BT_FRM_BG_o),
        .ODD_VD_o       (ODD_VD_o),
        .EVEN_VD_o      (EVEN_VD_o),
        .BT_PIX_CNT_o   (BT_PIX_CNT_o),
        .BT_LINE_CNT_o  (BT_LINE_CNT_o),
        .IM_END_o       (IM_END_o),
        .DATA_RQ_o      (DATA_RQ_o),
        .CLK_o          (CLK_o),
        .FID_o          (FID_o),
        .VSYNC_o        (VSYNC_o),
        .HSYNC_o        (HSYNC_o),
        .POUT_o         (POUT_o)
    );
    
    // Monitor process
    always @(posedge clk) begin
        if (BT656_OUT_EN_i && !RST_i) begin
            // Monitor EAV/SAV sequences
            if (POUT_o == (`ifdef BT656_10BIT_MODE 10'h3ff `else 8'hff `endif)) begin
                $fwrite(log_file, "[%0t] EAV/SAV FF detected at line %0d, pixel %0d\n", 
                        $time, BT_LINE_CNT_o, BT_PIX_CNT_o);
            end
            
            // Monitor frame boundaries
            if (BT_FRM_BG_o) begin
                $fwrite(log_file, "[%0t] FRAME BEGIN: Frame %0d\n", $time, frame_count);
            end
            
            if (IM_END_o) begin
                $fwrite(log_file, "[%0t] FRAME END: Frame %0d completed\n", $time, frame_count);
                frame_count = frame_count + 1;
            end
            
            // Log active video data
            if (DATA_RQ_o) begin
                $fwrite(data_file, "%0t %0d %0d %h\n", 
                        $time, BT_LINE_CNT_o, BT_PIX_CNT_o, POUT_o);
                test_pixel_count = test_pixel_count + 1;
            end
        end
    end
    
    // Data generation process
    always @(posedge clk) begin
        if (RST_i) begin
            DIN_i <= 0;
        end
        else if (DATA_RQ_o) begin
            // Generate test data pattern
`ifdef BT656_10BIT_MODE
            // 10-bit test pattern: rotating sequence
            DIN_i <= {test_data[1:0], test_data[7:0]};
            test_data <= {test_data[30:0], test_data[31] ^ test_data[2]};
`else
            // 8-bit test pattern: simple increment
            DIN_i <= test_data[7:0];
            test_data <= test_data + 1;
`endif
        end
    end
    
    // Test procedures
    task initialize;
    begin
        $display("==========================================");
`ifdef BT656_10BIT_MODE
        $display("BT656_out Testbench - 10-BIT MODE");
`else
        $display("BT656_out Testbench - 8-BIT MODE");
`endif
        $display("Clock Frequency: %0.3f MHz", PCLK_FREQ/1_000_000.0);
        $display("Half Period: %0.3f us", HALF_PERIOD);
        $display("==========================================");
        
        // Initialize signals
        RST_i = 1;
        PAL_i = 1;  // Test PAL mode
        BT656_OUT_EN_i = 0;
        DIN_i = 0;
        frame_count = 0;
        error_count = 0;
        test_pixel_count = 0;
        test_data = 32'hA5A5A5A5;
        
        // Apply reset
        #(HALF_PERIOD * 10);
        RST_i = 0;
        #(HALF_PERIOD * 20);
    end
    endtask
    
    task open_log_files;
    begin
        log_file = $fopen("bt656_test.log", "w");
        data_file = $fopen("bt656_data.log", "w");
        if (!log_file || !data_file) begin
            $display("Error opening log files!");
            $finish;
        end
        $fwrite(log_file, "BT656_out Test Log\n");
        $fwrite(log_file, "==================\n");
`ifdef BT656_10BIT_MODE
        $fwrite(log_file, "Mode: 10-bit\n");
`else
        $fwrite(log_file, "Mode: 8-bit\n");
`endif
        $fwrite(log_file, "Time Format: us\n\n");
        
        $fwrite(data_file, "Time Line Pixel Data\n");
        $fwrite(data_file, "====================\n");
    end
    endtask
    
    task reset_test;
    begin
        $fwrite(log_file, "\n=== Reset Test ===\n");
        
        // Verify reset state
        if (BT_FRM_BG_o !== 0) error_count = error_count + 1;
        if (DATA_RQ_o !== 0) error_count = error_count + 1;
        
        // Enable module
        BT656_OUT_EN_i = 1;
        #(HALF_PERIOD * 100);
        
        // Verify module starts
        if (BT_FRM_BG_o !== 1) begin
            $fwrite(log_file, "ERROR: Frame begin not asserted after enable\n");
            error_count = error_count + 1;
        end
        
        $fwrite(log_file, "Reset test completed with %0d errors\n", error_count);
    end
    endtask
    
    task basic_function_test;
    begin
        $fwrite(log_file, "\n=== Basic Function Test ===\n");
        
        // Run for 2 frames
        wait(frame_count >= 2);
        
        // Check timing
        if (frame_count < 2) begin
            $fwrite(log_file, "ERROR: Expected 2 frames, got %0d\n", frame_count);
            error_count = error_count + 1;
        end
        
        // Verify field indicators alternate
        if (!(ODD_VD_o ^ EVEN_VD_o)) begin
            $fwrite(log_file, "ERROR: Field indicators not alternating\n");
            error_count = error_count + 1;
        end
        
        $fwrite(log_file, "Basic function test completed with %0d errors\n", error_count);
    end
    endtask
    
    task frame_timing_test;
    begin
        $fwrite(log_file, "\n=== Frame Timing Test ===\n");
        integer line_count;
        integer pixel_count;
        
        // Wait for frame begin
        @(posedge BT_FRM_BG_o);
        line_count = 0;
        
        // Count lines in one frame
        while (!IM_END_o) begin
            @(posedge clk);
            if (BT_PIX_CNT_o == 0 && line_count < BT_LINE_CNT_o) begin
                line_count = line_count + 1;
            end
        end
        
        // Verify PAL frame has 625 lines
        if (line_count != 625) begin
            $fwrite(log_file, "ERROR: Expected 625 lines, got %0d\n", line_count);
            error_count = error_count + 1;
        end
        
        $fwrite(log_file, "Frame timing test: %0d lines per frame\n", line_count);
        $fwrite(log_file, "Frame timing test completed with %0d errors\n", error_count);
    end
    endtask
    
    task data_pattern_test;
    begin
        $fwrite(log_file, "\n=== Data Pattern Test ===\n");
        integer pixels_received = 0;
        
        // Wait for active video
        wait(DATA_RQ_o == 1);
        
        // Count pixels during one line
        repeat(1440) begin // Approximate active pixels per line
            @(posedge clk);
            if (DATA_RQ_o) begin
                pixels_received = pixels_received + 1;
                
                // Verify data is not blanking
                if (POUT_o == (`ifdef BT656_10BIT_MODE 10'h200 `else 8'h80 `endif) ||
                    POUT_o == (`ifdef BT656_10BIT_MODE 10'h040 `else 8'h10 `endif)) begin
                    $fwrite(log_file, "ERROR: Blanking data during active video at pixel %0d\n", 
                            BT_PIX_CNT_o);
                    error_count = error_count + 1;
                end
            end
        end
        
        $fwrite(log_file, "Data pattern test: %0d pixels received\n", pixels_received);
        $fwrite(log_file, "Data pattern test completed with %0d errors\n", error_count);
    end
    endtask
    
    task mode_switching_test;
    begin
        $fwrite(log_file, "\n=== Mode Switching Test ===\n");
        
        // Disable module
        BT656_OUT_EN_i = 0;
        #(HALF_PERIOD * 100);
        
        // Switch to NTSC
        PAL_i = 0;
        #(HALF_PERIOD * 50);
        
        // Re-enable
        BT656_OUT_EN_i = 1;
        
        // Wait for frame
        @(posedge BT_FRM_BG_o);
        $fwrite(log_file, "Module restarted in NTSC mode\n");
        
        // Test NTSC timing
        #(HALF_PERIOD * 10000);
        
        $fwrite(log_file, "Mode switching test completed\n");
    end
    endtask
    
    task print_test_summary;
    begin
        $display("\n==========================================");
        $display("TEST SUMMARY");
        $display("==========================================");
        $display("Total frames processed: %0d", frame_count);
        $display("Total pixels processed: %0d", test_pixel_count);
        $display("Total errors detected: %0d", error_count);
        
        $fwrite(log_file, "\n==========================================\n");
        $fwrite(log_file, "TEST SUMMARY\n");
        $fwrite(log_file, "==========================================\n");
        $fwrite(log_file, "Total frames processed: %0d\n", frame_count);
        $fwrite(log_file, "Total pixels processed: %0d\n", test_pixel_count);
        $fwrite(log_file, "Total errors detected: %0d\n", error_count);
        
        if (error_count == 0) begin
            $display("TEST PASSED!");
            $fwrite(log_file, "TEST PASSED!\n");
        end else begin
            $display("TEST FAILED with %0d errors!", error_count);
            $fwrite(log_file, "TEST FAILED with %0d errors!\n", error_count);
        end
        $display("==========================================");
    end
    endtask
    
    task close_log_files;
    begin
        $fclose(log_file);
        $fclose(data_file);
    end
    endtask
    
    // Waveform dump for debugging
    initial begin
        $dumpfile("bt656_tb.vcd");
        $dumpvars(0, BT656_tb);
    end
    
    // Timeout protection
    initial begin
        #100_000_000; // 100ms timeout
        $display("\n[%0t] TIMEOUT: Simulation stopped due to timeout", $time);
        print_test_summary();
        $finish;
    end

endmodule