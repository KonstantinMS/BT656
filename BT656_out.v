//////////////////////////////////////////////////////////////////////////////////
// Engineer:    Konstantin
// 
// Design Name: 
// Module Name: BT656_out
// Project Name: BT-656
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: -
// Additional Comments: Tested PAL only. To select a resolution, uncomment one of the lines below and change the clock frequency
// Encoding: UTF-8 
//////////////////////////////////////////////////////////////////////////////////

//`define BT_LINE_LENGTH              1716    //NTSC        PCLK = 13.5M
`define BT_LINE_LENGTH              1728    //PAL        PCLK = 13.5M
//`define BT_LINE_LENGTH              1560    //NTSC SQ        PCLK = 12.2727M
//`define BT_LINE_LENGTH              1888    //PAL SQ      PCLK = 14.75M

`timescale 1ns/1ps 
module BT656_out (
                 //  system reset & output clock 
                 input 	CLK_i,                  //  output clock   
                 input 	RST,                     //  system reset
                 
                 //  format from register
                 input           PAL_i, 
                 
                 //  enable                             
                 input           BT656_OUT_EN_i, //  BT656 out enable 
                 //  EBR data                    
                 input  [ 7 : 0] DIN_i,          //  data in 
                 //  BT656 frame begin           
				 output          BT_FRM_BG_o,    //  BT656 frame begin 
                 //  even/odd field / counting               
                 output          ODD_VD_o,       //  even field valid 
                 output          EVEN_VD_o,      //  odd  field valid 
                 output [10 : 0] BT_PIX_CNT_o,   //  pix count 
                 output [ 9 : 0] BT_LINE_CNT_o,  //  line count
                 output          IM_END_o,       //  image is end 
                 //  video data request       
                 output          DATA_RQ_o,      //  data request 
                 //  to video encode chip   
                 output          CLK_o,          //  clock      
                 output          FID_o,          //  odd/even field indicator
                 output          VSYNC_o,        //  vertical synchronization
                 output          HSYNC_o,        //  horizontal synchronization                     
                 output [ 7 : 0] POUT_o          //  data out  				 

                 ); 
               
               
//===============================================================  signal declaration 
reg           BT656_OUT_EN_i_d;
reg           bt_frm_bg; 
//
reg  [10 : 0] pix_cnt;       //  1728 per line  
wire          pix_cnt_end;   //  
reg  [ 9 : 0] line_cnt;      //  525/625  per frame for NTSC/PAL  
wire          line_cnt_end;

//   
wire          line_cnt_1;         
wire          line_cnt_3;
wire          line_cnt_4; 
wire          line_cnt_10;          
wire          line_cnt_23;
wire          line_cnt_263;
wire          line_cnt_266;
wire          line_cnt_270;
wire          line_cnt_286;
wire          line_cnt_311;
wire          line_cnt_313;
wire          line_cnt_317;
wire          line_cnt_336;    
wire          line_cnt_624;  
  

reg           F; 
reg           V;
reg           H;

reg           line_EAV0; 
reg           line_EAV1;
reg           line_EAV2;
reg           line_EAV3;
reg           line_BLANK; 
reg           line_data_rq; 
reg           line_EAV3_d; //  for HSYNC_o 

reg           fid; 
reg           vsync;
reg           vsync_d;  
reg           hsync; 
reg           even_out; 
reg           odd_out; 
reg  [ 7 : 0] pdata; 
 
wire          go_vb1; 
wire          go_odd; 
wire          go_vb2; 
wire          go_even;
wire          go_vb3;                  

//  state machine  
parameter S_IDLE  = 1; 
parameter S_VB1   = 2; 
parameter S_ODD   = 3; 
parameter S_VB2   = 4; 
parameter S_EVEN  = 5; 
parameter S_VB3   = 6;

reg [ 2 : 0] state;  
reg count = 1'b0;


//===============================================================  implementation  
//-----------------------------------------------  BT656_OUT_EN_i_d 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		BT656_OUT_EN_i_d <= 0; 
	else 
		BT656_OUT_EN_i_d <= BT656_OUT_EN_i;	 				
end

//-----------------------------------------------  bt_frm_bg  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		bt_frm_bg <= 0; 
	else 
		if (state == S_VB1)
			bt_frm_bg <= 1;  
		else 
			bt_frm_bg <= 0;	 				
end

//-----------------------------------------------  BT_FRM_BG_o 
assign BT_FRM_BG_o = bt_frm_bg; 


//-----------------------------------------------  go state 
assign go_vb1  = (BT656_OUT_EN_i ^ BT656_OUT_EN_i_d) | line_cnt_end; 
assign go_odd  = line_cnt_23; 
assign go_vb2  = (line_cnt_263 & ~PAL_i) | (line_cnt_311 & PAL_i);  
assign go_even = (line_cnt_286 & ~PAL_i) | (line_cnt_336 & PAL_i); 
assign go_vb3  = line_cnt_624 & PAL_i; 




/////////////////////////////////////////////////////////////////  state machine  
//  state machine  
/////////////////////////////////////////////////////////////////    
always @(posedge CLK_i or posedge RST) 
begin 
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
				if (go_vb3)        //  PAL 
					state <= S_VB3;
				else if (go_vb1)   //  NTSC 
					state <= S_VB1; 				
				else 
					state <= S_EVEN; 					 
			S_VB3 :   //  PAL  
				if (go_vb1) 
					state <= S_VB1;
				else 
					state <= S_VB3; 																				
			default : 
				state <= S_IDLE; 
		endcase 					 								
end



/////////////////////////////////////////////////////////////////     
//   line & pixel counting  
///////////////////////////////////////////////////////////////// 
 
//-----------------------------------------------  pix_cnt 
//  pix_cnt
//-----------------------------------------------  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		pix_cnt <= 0; 
	else 
		if (pix_cnt_end)
			pix_cnt <= 0;  
		else if (state != S_IDLE) 
			pix_cnt <= pix_cnt + 1'b1;	 				
end

//-----------------------------------------------  pix_cnt_end 
assign pix_cnt_end = pix_cnt == `BT_LINE_LENGTH-1; 
                            

//-----------------------------------------------  line_cnt 
//  line_cnt  
//-----------------------------------------------
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_cnt <= 0; 
	else 
		if (line_cnt_end) //  return to 0 
			line_cnt <= 0;
		else if (pix_cnt_end) 
			line_cnt <= line_cnt + 1'b1; 				
end 

//-----------------------------------------------  line_cnt_end 
assign line_cnt_end = (line_cnt == 525 & ~PAL_i) | 
                      (line_cnt == 625);

//-----------------------------------------------  
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


//-----------------------------------------------  F 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		F <= 0; 
	else 
		if (~PAL_i) begin  //  NTSC 
			if (line_cnt_1) 
				F <= 1;
			else if (line_cnt_4) 
				F <= 0;
			else if (line_cnt_266) 
				F <= 1;
			end 
		else begin           //  PAL 
			if (line_cnt_1) 
				F <= 0;
			else if (line_cnt_313) 
				F <= 1;
			end		
end

//-----------------------------------------------  V  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		V <= 0; 
	else 
		V <= ~(state == S_ODD || state == S_EVEN);  				
end

//-----------------------------------------------  H  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		H <= 0; 
	else 
		H <= (pix_cnt <= 283); 				
end


//-----------------------------------------------  line_EAV0 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_EAV0 <= 0; 
	else 
		if (state != S_IDLE && (pix_cnt == 0 || pix_cnt == 284)) 
			line_EAV0 <= 1'b1;
		else 
			line_EAV0 <= 1'b0; 				
end  

//-----------------------------------------------  line_EAV1 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_EAV1 <= 0; 
	else 
		if (pix_cnt == 1 || pix_cnt == 285) 
			line_EAV1 <= 1'b1;
		else 
			line_EAV1 <= 1'b0; 				
end

//-----------------------------------------------  line_EAV2 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_EAV2 <= 0; 
	else 
		if (pix_cnt == 2 || pix_cnt == 286) 
			line_EAV2 <= 1'b1;
		else 
			line_EAV2 <= 1'b0; 				
end

//-----------------------------------------------  line_EAV3 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_EAV3 <= 0; 
	else 
		if (pix_cnt == 3 || pix_cnt == 287) 
			line_EAV3 <= 1'b1;
		else 
			line_EAV3 <= 1'b0; 				
end


//-----------------------------------------------  line_EAV3_d 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_EAV3_d <= 0; 
	else 
		line_EAV3_d <= line_EAV3; 			
end

//-----------------------------------------------  line_BLANK  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_BLANK <= 0; 
	else 
		if (pix_cnt > 3 && pix_cnt < 284) 
			line_BLANK <= 1'b1;
		else 
			line_BLANK <= 1'b0; 				
end

//-----------------------------------------------  line_data_rq 
//
//-----------------------------------------------   
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		line_data_rq <= 0; 
	else 
		if (pix_cnt >= 287 && (pix_cnt <= `BT_LINE_LENGTH-2) && (state == S_ODD || state == S_EVEN)) 
			line_data_rq <= 1'b1;
		else 
			line_data_rq <= 1'b0; 				
end

//-----------------------------------------------  even_out  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		even_out <= 0; 
	else 
		even_out <= ~F;			
end

//-----------------------------------------------  odd_out  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		odd_out <= 0; 
	else 
		odd_out <= F;			
end

//-----------------------------------------------  fid   
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		fid <= 0; 
	else 
		fid <= F;    //  0 -- ODD; 1 -- EVEN 			
end

//-----------------------------------------------  vsync  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		vsync <= 0; 
	else 
		if (~PAL_i) begin  //  NTSC 
			if (line_cnt_4 | (line_cnt_266 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
				vsync <= 1;
			else if (line_cnt_10 | (line_cnt_270 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
				vsync <= 0;
			end	
		else begin           //  PAL 
			if (line_cnt_4 | (line_cnt_313 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
				vsync <= 1;
			else if (line_cnt_10 | (line_cnt_317 & pix_cnt == `BT_LINE_LENGTH/2-1)) 
				vsync <= 0;
			end 
end

//-----------------------------------------------  vsync_d  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		vsync_d <= 0; 
	else 
		vsync_d <= vsync; 	
end

//-----------------------------------------------  hsync  
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
		hsync <= 0; 
	else 
		if (line_EAV3_d & ~H) 
			hsync <= 1'b0;  //  data active 	
		else if (line_EAV0) 
			hsync <= 1'b1;		
end


//-----------------------------------------------  pdata 
always @(posedge CLK_i or posedge RST) 
begin 
	if (RST)
    begin
		pdata <= 0; 
	end
    else
    begin
	    if (line_EAV0) 
	    	pdata <= 8'hff; 
	    else if (line_EAV1) 
	    	pdata <= 8'h00; 	
	    else if (line_EAV2) 
	    	pdata <= 8'h00; 			
	    else if (line_EAV3) 
	    	pdata <= {1'b1, F, V, H, V^H, F^H, F^V, F^V^H};
	    else if (line_BLANK) 
		begin 
	    	if (pix_cnt[0])        // 1 -- 80, because of delaying 2 clock     
	    		pdata <= 8'h80;	
	    	else if (~pix_cnt[0])  // 0 -- 10, because of delaying 2 clock
	    		pdata <= 8'h10;	
	    end 
	    else 
		begin 
            // for debug
            case (pix_cnt[1:0]) 
                0:
                    pdata <=  240;  //cr
                1:
                    pdata <=  193;  // y
                2:
                    pdata <=  90;  //cb
                3:
                    pdata <=  193;  // y
                endcase
	    	/*
            // for release
            pdata <= DIN_i;
            */	
		end
	end					
end 


/////////////////////////////////////////////////////////////////  output       
//   
///////////////////////////////////////////////////////////////// 
//-----------------------------------------------  ODD_VD_o  
assign ODD_VD_o = even_out; 

//-----------------------------------------------  EVEN_VD_o    
assign EVEN_VD_o = odd_out; 

//-----------------------------------------------  DATA_RQ_o  
assign DATA_RQ_o = line_data_rq; 

//-----------------------------------------------  CLK_o 
assign CLK_o = ~CLK_i; 

//-----------------------------------------------  FID_o 
assign FID_o = fid; 
//-----------------------------------------------  VSYNC_o 
assign VSYNC_o = vsync_d; 
//-----------------------------------------------  HSYNC_o 
assign HSYNC_o = hsync; 
//-----------------------------------------------  POUT_o 
assign POUT_o = pdata; 

//-----------------------------------------------  BT_PIX_CNT_o 
assign BT_PIX_CNT_o = pix_cnt; 
//-----------------------------------------------  BT_LINE_CNT_o
assign BT_LINE_CNT_o = line_cnt; 

assign IM_END_o = line_cnt_end; 


endmodule 