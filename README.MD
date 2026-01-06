# BT656_out - BT.656 Video Encoder Module

## Overview
The `BT656_out` module is an 8-bit BT.656 video encoder that converts raw pixel data into a standard BT.656 video stream. This implementation supports both NTSC and PAL video formats and has been tested on the svga050 platform from olightek.

## Features
- Supports both NTSC and PAL video standards
- Configurable line lengths for different pixel clock frequencies
- Field-based (odd/even) video output
- Integrated synchronization signal generation (VSYNC, HSYNC)
- EAV/SAV timing sequence generation
- Data request interface for external memory/fifo
- Debug mode for test pattern generation

## Parameters
The module uses a `BT_LINE_LENGTH` macro definition to set the number of pixels per line. Select the appropriate line length based on your video standard and pixel clock:

- `1728` - PAL (13.5 MHz pixel clock) ← **Default**
- `1716` - NTSC (13.5 MHz pixel clock)
- `1560` - NTSC SQ (12.2727 MHz pixel clock)
- `1888` - PAL SQ (14.75 MHz pixel clock)

## Port Description

### Inputs
- `CLK_i` - Input clock (should match pixel clock frequency)
- `RST` - Active-high system reset
- `PAL_i` - Format selection (0 = NTSC, 1 = PAL)
- `BT656_OUT_EN_i` - Module enable signal
- `DIN_i[7:0]` - Input pixel data (Y/Cb/Cr components)

### Outputs
- `BT_FRM_BG_o` - Frame begin indicator
- `ODD_VD_o` - Even field valid indicator
- `EVEN_VD_o` - Odd field valid indicator
- `BT_PIX_CNT_o[10:0]` - Current pixel counter
- `BT_LINE_CNT_o[9:0]` - Current line counter
- `IM_END_o` - Image end indicator
- `DATA_RQ_o` - Data request for next pixel
- `CLK_o` - Output clock (inverted input clock)
- `FID_o` - Field ID (0 = odd, 1 = even)
- `VSYNC_o` - Vertical synchronization
- `HSYNC_o` - Horizontal synchronization
- `POUT_o[7:0]` - BT.656 encoded output data

## Timing Specifications
- NTSC: 525 lines per frame (odd: 1-263, even: 264-525)
- PAL: 625 lines per frame (odd: 1-313, even: 314-625)
- Each line contains EAV (End of Active Video) and SAV (Start of Active Video) sequences
- Blanking intervals with 0x80 (Cb) and 0x10 (Y) values

## State Machine
The module implements a 6-state state machine:
1. `S_IDLE` - Initial state, waiting for enable
2. `S_VB1` - First vertical blanking period
3. `S_ODD` - Odd field active video
4. `S_VB2` - Second vertical blanking period
5. `S_EVEN` - Even field active video
6. `S_VB3` - Third vertical blanking period (PAL only)

## Debug Mode
Enable debug mode by uncommenting `//`define DEBUG_BT656` to generate a test pattern:
- Pattern sequence: 240(Cr), 193(Y), 90(Cb), 193(Y) repeating

## Usage Notes
1. Select the appropriate `BT_LINE_LENGTH` definition for your video standard
2. Ensure the input clock matches the required pixel clock frequency
3. The module expects YCbCr 4:2:2 format input data
4. Data should be provided when `DATA_RQ_o` is asserted
5. Reset the module before enabling video output

## File Information
- **Designer**: Konstantin
- **Encoding**: UTF-8
- **Tested Platform**: svga050 @olightek
- **Timescale**: 1ns/1ps

## Dependencies
- No external dependencies required
- Uses Verilog-2001 syntax

## Status Signals
- `BT_PIX_CNT_o` and `BT_LINE_CNT_o` provide real-time timing information
- `IM_END_o` pulses high at the end of each frame
- `BT_FRM_BG_o` pulses high at the beginning of each frame