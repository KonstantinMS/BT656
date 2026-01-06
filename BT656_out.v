//////////////////////////////////////////////////////////////////////////////////
// Engineer:    Konstantin
// 
// Design Name: 
// Module Name: BT656_out
// Project Name: BT-656 coder, 8/10 bit
// Additional Comments: 
//  - Tested on svga050 @olightek. 
//  - To select a resolution, uncomment one of the lines below and adjust the frequency of your design.
//  - Supports 8-bit and 10-bit modes with backward compatibility
// Encoding: UTF-8 
//////////////////////////////////////////////////////////////////////////////////

//`define BT_LINE_LENGTH              1716    //NTSC        PCLK = 13.5M
`define BT_LINE_LENGTH                1728    //PAL        PCLK = 13.5M
//`define BT_LINE_LENGTH              1560    //NTSC SQ        PCLK = 12.2727M
//`define BT_LINE_LENGTH              1888    //PAL SQ      PCLK = 14.75M
//`define DEBUG_BT656 

// Mode selection: uncomment for 10-bit mode, comment for 8-bit mode
//`define BT656_10BIT_MODE

`timescale 1ns/1ps 

module BT656_out (
    // System reset & output clock 
    input  CLK_i,                    // Input clock   
    input  RST,                      // System reset
    
    // Format from register
    input  PAL_i, 
    
    // Enable                             
    input  BT656_OUT_EN_i,           // BT656 out enable 
    
    // EBR data (8-bit or 10-bit depending on mode)
`ifdef BT656_10BIT_MODE
    input  [9:0] DIN_i,              // 10-bit data in
`else
    input  [7:0] DIN_i,              // 8-bit data in
`endif
    
    // BT656 frame begin           
    output BT_FRM_BG_o,              // BT656 frame begin 
    
    // Even/odd field / counting               
    output ODD_VD_o,                 // Even field valid 
    output EVEN_VD_o,                // Odd field valid 
    output [10:0] BT_PIX_CNT_o,      // Pixel count 
    output [9:0] BT_LINE_CNT_o,      // Line count
    output IM_END_o,                 // Image is end 
    
    // Video data request       
    output DATA_RQ_o,                // Data request 
    
    // To video encode chip   
    output CLK_o,                    // Clock      
    output FID_o,                    // Odd/even field indicator
    output VSYNC_o,                  // Vertical synchronization
    output HSYNC_o,                  // Horizontal synchronization                     
    
    // Data output (8-bit or 10-bit depending on mode)
`ifdef BT656_10BIT_MODE
    output [9:0] POUT_o              // 10-bit data out
`else
    output [7:0] POUT_o              // 8-bit data out
`endif
); 
               
//=============================================================== Signal declaration 
reg           BT656_OUT_EN_i_d;
reg           bt_frm_bg; 

reg  [10:0] pix_cnt;       // BT_LINE_LENGTH per line  
wire         pix_cnt_end;  // End of pixel count
reg  [9:0]  line_cnt;      // 525/625 per frame for NTSC/PAL  
wire         line_cnt_end;

// Line counter comparators  
wire         line_cnt_1;         
wire         line_cnt_3;
wire         line_cnt_4; 
wire         line_cnt_10;          
wire         line_cnt_23;
wire         line_cnt_263;
wire         line_cnt_266;
wire         line_cnt_270;
wire         line_cnt_286;
wire         line_cnt_311;
wire         line_cnt_313;
wire         line_cnt_317;
wire         line_cnt_336;    
wire         line_cnt_624;  

reg          F;            // Field flag
reg          V;            // Vertical blanking
reg          H;            // Horizontal blanking

reg          line_EAV0; 
reg          line_EAV1;
reg          line_EAV2;
reg          line_EAV3;
reg          line_BLANK; 
reg          line_data_rq; 
reg          line_EAV3_d;  // Delayed for HSYNC generation 

reg          fid;          // Field ID
reg          vsync;
reg          vsync_d;  
reg          hsync; 
reg          even_out; 
reg          odd_out; 

`ifdef BT656_10BIT_MODE
reg  [9:0]  pdata;        // 10-bit pixel data
`else
reg  [7:0]  pdata;        // 8-bit pixel data
`endif

// State machine control signals
wire         go_vb1; 
wire         go_odd; 
wire         go_vb2; 
wire         go_even;
wire         go_vb3;                  

// State machine  
parameter S_IDLE  = 3'd1; 
parameter S_VB1   = 3'd2; 
parameter S_ODD   = 3'd3; 
parameter S_VB2   = 3'd4; 
parameter S_EVEN  = 3'd5; 
parameter S_VB3   = 3'd6;

reg [2:0] state;  

//=============================================================== Implementation  

//----------------------------------------------- BT656_OUT_EN_i_d 
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        BT656_OUT_EN_i_d <= 0; 
    else 
        BT656_OUT_EN_i_d <= BT656_OUT_EN_i;	 				
end

//----------------------------------------------- bt_frm_bg  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        bt_frm_bg <= 0; 
    else if (state == S_VB1)
        bt_frm_bg <= 1;  
    else 
        bt_frm_bg <= 0;	 				
end

//----------------------------------------------- BT_FRM_BG_o 
assign BT_FRM_BG_o = bt_frm_bg; 

//----------------------------------------------- State transition signals 
assign go_vb1  = (BT656_OUT_EN_i ^ BT656_OUT_EN_i_d) | line_cnt_end; 
assign go_odd  = line_cnt_23; 
assign go_vb2  = (line_cnt_263 & ~PAL_i) | (line_cnt_311 & PAL_i);  
assign go_even = (line_cnt_286 & ~PAL_i) | (line_cnt_336 & PAL_i); 
assign go_vb3  = line_cnt_624 & PAL_i; 

///////////////////////////////////////////////////////////////// State machine  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        state <= S_IDLE; 
    else 
        case (state) 
            S_IDLE : 
                if (go_vb1)
                    state <= S_VB1; 
                else 
                    state <= S_IDLE;  
            
            S_VB1 : 
                if (go_odd) 
                    state <= S_ODD;
                else 
                    state <= S_VB1; 
            
            S_ODD : 
                if (go_vb2) 
                    state <= S_VB2;
                else 
                    state <= S_ODD; 
            
            S_VB2 : 
                if (go_even) 
                    state <= S_EVEN;
                else 
                    state <= S_VB2;
            
            S_EVEN : 
                if (go_vb3)         // PAL 
                    state <= S_VB3;
                else if (go_vb1)    // NTSC 
                    state <= S_VB1; 				
                else 
                    state <= S_EVEN; 					 
            
            S_VB3 :                 // PAL only
                if (go_vb1) 
                    state <= S_VB1;
                else 
                    state <= S_VB3; 
            
            default : 
                state <= S_IDLE; 
        endcase 					 								
end

/////////////////////////////////////////////////////////////////     
//   Line & pixel counting  
///////////////////////////////////////////////////////////////// 
 
//----------------------------------------------- pix_cnt 
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        pix_cnt <= 0; 
    else if (pix_cnt_end)
        pix_cnt <= 0;  
    else if (state != S_IDLE) 
        pix_cnt <= pix_cnt + 1'b1;	 				
end

//----------------------------------------------- pix_cnt_end 
assign pix_cnt_end = pix_cnt == (`BT_LINE_LENGTH - 1); 

//----------------------------------------------- line_cnt  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_cnt <= 0; 
    else if (line_cnt_end) // Return to 0 
        line_cnt <= 0;
    else if (pix_cnt_end) 
        line_cnt <= line_cnt + 1'b1; 				
end 

//----------------------------------------------- line_cnt_end 
assign line_cnt_end = (line_cnt == 525 & ~PAL_i) | (line_cnt == 625);

//----------------------------------------------- Line counter comparators  
assign line_cnt_1   = line_cnt == 0;
assign line_cnt_3   = line_cnt == 2; 
assign line_cnt_4   = line_cnt == 3;
assign line_cnt_10  = line_cnt == 9;    
assign line_cnt_23  = line_cnt == 22; 
assign line_cnt_263 = line_cnt == 262;
assign line_cnt_266 = line_cnt == 265;
assign line_cnt_270 = line_cnt == 269; 
assign line_cnt_286 = line_cnt == 285;   
assign line_cnt_311 = line_cnt == 310;
assign line_cnt_313 = line_cnt == 312;
assign line_cnt_317 = line_cnt == 316;   
assign line_cnt_336 = line_cnt == 335;  
assign line_cnt_624 = line_cnt == 623;                                         

//----------------------------------------------- F (Field flag)
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        F <= 0; 
    else if (~PAL_i) begin  // NTSC 
        if (line_cnt_1) 
            F <= 1;
        else if (line_cnt_4) 
            F <= 0;
        else if (line_cnt_266) 
            F <= 1;
    end 
    else begin              // PAL 
        if (line_cnt_1) 
            F <= 0;
        else if (line_cnt_313) 
            F <= 1;
    end		
end

//----------------------------------------------- V (Vertical blanking)  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        V <= 0; 
    else 
        V <= ~(state == S_ODD || state == S_EVEN);  				
end

//----------------------------------------------- H (Horizontal blanking)  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        H <= 0; 
    else 
        H <= (pix_cnt <= 283); 				
end

//----------------------------------------------- EAV/SAV timing signals
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_EAV0 <= 0; 
    else if (state != S_IDLE && (pix_cnt == 0 || pix_cnt == 284)) 
        line_EAV0 <= 1'b1;
    else 
        line_EAV0 <= 1'b0; 				
end  

always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_EAV1 <= 0; 
    else if (pix_cnt == 1 || pix_cnt == 285) 
        line_EAV1 <= 1'b1;
    else 
        line_EAV1 <= 1'b0; 				
end

always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_EAV2 <= 0; 
    else if (pix_cnt == 2 || pix_cnt == 286) 
        line_EAV2 <= 1'b1;
    else 
        line_EAV2 <= 1'b0; 				
end

always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_EAV3 <= 0; 
    else if (pix_cnt == 3 || pix_cnt == 287) 
        line_EAV3 <= 1'b1;
    else 
        line_EAV3 <= 1'b0; 				
end

//----------------------------------------------- line_EAV3_d (for HSYNC generation)
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_EAV3_d <= 0; 
    else 
        line_EAV3_d <= line_EAV3; 			
end

//----------------------------------------------- line_BLANK  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_BLANK <= 0; 
    else if (pix_cnt > 3 && pix_cnt < 284) 
        line_BLANK <= 1'b1;
    else 
        line_BLANK <= 1'b0; 				
end

//----------------------------------------------- line_data_rq (data request)
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        line_data_rq <= 0; 
    else if (pix_cnt >= 287 && (pix_cnt <= `BT_LINE_LENGTH-2) && (state == S_ODD || state == S_EVEN)) 
        line_data_rq <= 1'b1;
    else 
        line_data_rq <= 1'b0; 				
end

//----------------------------------------------- Field output signals  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        even_out <= 0; 
    else 
        even_out <= ~F;			
end

always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        odd_out <= 0; 
    else 
        odd_out <= F;			
end

//----------------------------------------------- fid (Field ID)
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        fid <= 0; 
    else 
        fid <= F;    // 0 = odd; 1 = even 			
end

//----------------------------------------------- vsync  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        vsync <= 0; 
    else if (~PAL_i) begin  // NTSC 
        if (line_cnt_4 | (line_cnt_266 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
            vsync <= 1;
        else if (line_cnt_10 | (line_cnt_270 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
            vsync <= 0;
    end	
    else begin              // PAL 
        if (line_cnt_4 | (line_cnt_313 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
            vsync <= 1;
        else if (line_cnt_10 | (line_cnt_317 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
            vsync <= 0;
    end 
end

//----------------------------------------------- vsync_d  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        vsync_d <= 0; 
    else 
        vsync_d <= vsync; 	
end

//----------------------------------------------- hsync  
always @(posedge CLK_i or posedge RST) begin 
    if (RST)
        hsync <= 0; 
    else if (line_EAV3_d & ~H) 
        hsync <= 1'b0;  // Data active period
    else if (line_EAV0) 
        hsync <= 1'b1;	// Blanking period	
end

//----------------------------------------------- pdata generation
// 10-bit mode support with backward compatibility
always @(posedge CLK_i or posedge RST) begin 
    if (RST) begin
        pdata <= 0; 
    end
    else begin
        // EAV/SAV sequences and blanking
        if (line_EAV0) begin
            pdata <= `ifdef BT656_10BIT_MODE 10'h3ff `else 8'hff `endif; 
        end
        else if (line_EAV1) begin
            pdata <= `ifdef BT656_10BIT_MODE 10'h000 `else 8'h00 `endif; 	
        end
        else if (line_EAV2) begin
            pdata <= `ifdef BT656_10BIT_MODE 10'h000 `else 8'h00 `endif; 			
        end
        else if (line_EAV3) begin
            // EAV/SAV word with protection bits
`ifdef BT656_10BIT_MODE
            // 10-bit format: {P3, P2, P1, P0, F, V, H, D1, D0}
            // D1 = V^H, D0 = F^V^H, P0 = F^H, P1 = F^V, P2 = V^H, P3 = F^V^H
            pdata <= {1'b1, F, V, H, (V^H), (F^H), (F^V), (V^H), (F^V^H)};
`else
            // 8-bit format: {1'b1, F, V, H, P3, P2, P1, P0}
            pdata <= {1'b1, F, V, H, (F^V^H), (V^H), (F^V), (F^H)};
`endif
        end
        else if (line_BLANK) begin 
            // Blanking data (Cb/Y values)
            if (pix_cnt[0]) begin       // 1 -- Cb component (0x80 in 8-bit, 0x200 in 10-bit)
                pdata <= `ifdef BT656_10BIT_MODE 10'h200 `else 8'h80 `endif;
            end
            else begin                  // 0 -- Y component (0x10 in 8-bit, 0x040 in 10-bit)
                pdata <= `ifdef BT656_10BIT_MODE 10'h040 `else 8'h10 `endif;
            end
        end 
        else begin 
            // Active video data
`ifdef DEBUG_BT656
            // Debug pattern
`ifdef BT656_10BIT_MODE
            case (pix_cnt[1:0]) 
                0: pdata <= 10'd240;  // Cr
                1: pdata <= 10'd193;  // Y
                2: pdata <= 10'd90;   // Cb
                3: pdata <= 10'd193;  // Y
            endcase
`else
            case (pix_cnt[1:0]) 
                0: pdata <= 8'd240;  // Cr
                1: pdata <= 8'd193;  // Y
                2: pdata <= 8'd90;   // Cb
                3: pdata <= 8'd193;  // Y
            endcase
`endif
`else
            // Normal operation - pass through input data
            // Note: In 10-bit mode, input is expected to be 10-bit YCbCr data
            // In 8-bit mode, input is expected to be 8-bit YCbCr data
            pdata <= DIN_i;
`endif	
        end
    end					
end 

///////////////////////////////////////////////////////////////// Output       
///////////////////////////////////////////////////////////////// 
assign ODD_VD_o      = even_out; 
assign EVEN_VD_o     = odd_out; 
assign DATA_RQ_o     = line_data_rq; 
assign CLK_o         = ~CLK_i; 
assign FID_o         = fid; 
assign VSYNC_o       = vsync_d; 
assign HSYNC_o       = hsync; 
assign POUT_o        = pdata; 
assign BT_PIX_CNT_o  = pix_cnt; 
assign BT_LINE_CNT_o = line_cnt; 
assign IM_END_o      = line_cnt_end; 

endmodule