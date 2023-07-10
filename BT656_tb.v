`timescale 1us / 1ns


//////////////////////////////////////////////////////////////////////////////////
// Design Name: simple tb
//////////////////////////////////////////////////////////////////////////////////


module BT656_tb(    );
    real  half_clk = 1.0 / 13_500_000 /  2 * 1_000_000;
    `define HALF_CLK   half_clk
    reg clk;
    reg RST_i;


    initial
    begin
        clk <= 0;
        RST_i <= 1;
        #`HALF_CLK RST_i <= 0;
    end

    always
    #`HALF_CLK clk <= !clk;

    BT656_out BT656_0 (
        .CLK_i          ( clk ),
        .RST            ( RST_i ),
        .PAL_i          ( 1 ),
        .BT656_OUT_EN_i ( 1 ),
        .DIN_i          (  ),
        .BT_FRM_BG_o    (  ),
        .ODD_VD_o       (  ),
        .EVEN_VD_o      (  ),
        .BT_PIX_CNT_o   (  ),
        .BT_LINE_CNT_o  (  ),
        .IM_END_o       (  ),
        .DATA_RQ_o      (  ),
        .CLK_o          (  ),
        .FID_o          (  ),
        .VSYNC_o        (  ),
        .HSYNC_o        (  ),
        .POUT_o         (  )
    );

endmodule
