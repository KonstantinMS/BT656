# BT656_out - BT.656 Video Encoder Module
![License](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)

## Overview

The `BT656_out` module is a configurable BT.656 video encoder that supports both 8-bit and 10-bit video output formats. This implementation provides standard-compliant BT.656 video stream generation with support for both NTSC and PAL video standards. The module has been tested on the svga050 platform from olightek.

## Features

### Core Features
- **Dual Mode Support**: Configurable 8-bit or 10-bit operation
- **Multi-format Support**: NTSC and PAL video standards
- **Field-based Output**: Proper odd/even field sequencing
- **Complete Timing Generation**: VSYNC, HSYNC, EAV/SAV sequences
- **Data Interface**: Simple request/response data interface

### 8-bit Mode Features
- Standard BT.656 compliant output
- 8-bit YCbCr 4:2:2 format
- Compatible with legacy systems

### 10-bit Mode Features
- Extended dynamic range support
- BT.1120 compatible protection bits
- Backward compatible with 8-bit systems
- Improved video quality

## Module Parameters

### Configuration Macros

```verilog
// Resolution selection (uncomment one):
// `define BT_LINE_LENGTH 1716    // NTSC, 13.5 MHz pixel clock
`define BT_LINE_LENGTH 1728       // PAL, 13.5 MHz pixel clock (Default)
// `define BT_LINE_LENGTH 1560    // NTSC SQ, 12.2727 MHz pixel clock
// `define BT_LINE_LENGTH 1888    // PAL SQ, 14.75 MHz pixel clock

// Mode selection:
// `define BT656_10BIT_MODE       // Uncomment for 10-bit mode

// Debug features:
// `define DEBUG_BT656            // Test pattern generation
```

### Timing Specifications
| Standard | Lines/Frame | Pixel Clock | Line Length |
|----------|-------------|-------------|-------------|
| NTSC     | 525         | 13.5 MHz    | 1716        |
| PAL      | 625         | 13.5 MHz    | 1728        |
| NTSC SQ  | 525         | 12.2727 MHz | 1560        |
| PAL SQ   | 625         | 14.75 MHz   | 1888        |

## Interface Description

### Port Definition

```verilog
module BT656_out (
    // System Interface
    input  CLK_i,                    // Pixel clock input
    input  RST,                      // Active-high reset
    
    // Configuration
    input  PAL_i,                    // 0=NTSC, 1=PAL
    
    // Control
    input  BT656_OUT_EN_i,           // Module enable
    
    // Data Interface (width depends on mode)
    input  [MODE_WIDTH-1:0] DIN_i,   // Video data input
    
    // Status Outputs
    output BT_FRM_BG_o,              // Frame begin pulse
    output ODD_VD_o,                 // Odd field valid
    output EVEN_VD_o,                // Even field valid
    output [10:0] BT_PIX_CNT_o,      // Pixel counter
    output [9:0]  BT_LINE_CNT_o,     // Line counter
    output IM_END_o,                 // Image end indicator
    output DATA_RQ_o,                // Data request
    
    // Video Outputs
    output CLK_o,                    // Output clock (inverted)
    output FID_o,                    // Field ID (0=odd, 1=even)
    output VSYNC_o,                  // Vertical sync
    output HSYNC_o,                  // Horizontal sync
    output [MODE_WIDTH-1:0] POUT_o   // Video data output
);
```

**Note**: `MODE_WIDTH` is 10 for 10-bit mode, 8 for 8-bit mode.

## Data Format

### 8-bit Mode Data Mapping
```
EAV/SAV Word: {1'b1, F, V, H, P3, P2, P1, P0}
Where:
  F = Field flag
  V = Vertical blanking
  H = Horizontal blanking
  P0-P3 = Protection bits (XOR combinations of F, V, H)
```

### 10-bit Mode Data Mapping
```
EAV/SAV Word: {P3, P2, P1, P0, F, V, H, D1, D0}
Where:
  D0 = F^V^H
  D1 = V^H
  P0 = F^H
  P1 = F^V
  P2 = V^H
  P3 = F^V^H
```

### Blanking Values
| Component | 8-bit Value | 10-bit Value | Description |
|-----------|-------------|--------------|-------------|
| Cb        | 0x80        | 0x200        | Chroma blank |
| Y         | 0x10        | 0x040        | Luma blank |

## State Machine

The module implements a 6-state finite state machine:

```verilog
parameter S_IDLE  = 3'd1;   // Initial state, waiting for enable
parameter S_VB1   = 3'd2;   // First vertical blanking
parameter S_ODD   = 3'd3;   // Odd field active video
parameter S_VB2   = 3'd4;   // Second vertical blanking
parameter S_EVEN  = 3'd5;   // Even field active video
parameter S_VB3   = 3'd6;   // Third vertical blanking (PAL only)
```

### State Transitions
```
S_IDLE → S_VB1   : When enabled or frame ends
S_VB1  → S_ODD   : After line 22
S_ODD  → S_VB2   : After line 262 (NTSC) or 310 (PAL)
S_VB2  → S_EVEN  : After line 285 (NTSC) or 335 (PAL)
S_EVEN → S_VB3   : PAL only, after line 623
S_EVEN → S_VB1   : NTSC, when frame ends
S_VB3  → S_VB1   : PAL, when frame ends
```

## Usage Examples

### 8-bit Mode Instantiation
```verilog
// No define needed for 8-bit mode
BT656_out bt656_inst (
    .CLK_i          (pixel_clk),
    .RST            (reset),
    .PAL_i          (1'b1),        // PAL mode
    .BT656_OUT_EN_i (enable),
    .DIN_i          (video_data_8bit),
    // ... connect other ports
    .POUT_o         (bt656_output_8bit)
);
```

### 10-bit Mode Instantiation
```verilog
// Define BT656_10BIT_MODE before including module
`define BT656_10BIT_MODE

BT656_out bt656_10bit_inst (
    .CLK_i          (pixel_clk),
    .RST            (reset),
    .PAL_i          (1'b0),        // NTSC mode
    .BT656_OUT_EN_i (enable),
    .DIN_i          (video_data_10bit),
    // ... connect other ports
    .POUT_o         (bt656_output_10bit)
);
```

### Timing Requirements
1. Provide stable pixel clock at the appropriate frequency
2. Assert reset before enabling the module
3. Provide video data when DATA_RQ_o is asserted
4. Data should be in YCbCr 4:2:2 format

## Debug Features

### Test Pattern Generation
Enable debug mode to generate a rotating test pattern:
```verilog
`define DEBUG_BT656
```
Pattern sequence: Cr(240), Y(193), Cb(90), Y(193)

### Monitoring Signals
Key signals for debugging:
- `BT_PIX_CNT_o` / `BT_LINE_CNT_o`: Current position in frame
- `BT_FRM_BG_o`: Frame synchronization
- `DATA_RQ_o`: Data request timing
- `FID_o`: Field identification

## Testing

### Testbench Support
A comprehensive testbench is provided with:
- Automatic mode detection (8/10 bit)
- Multi-test suite execution
- File logging and waveform generation
- Error detection and reporting

### Running Tests
```bash
# 8-bit mode test
iverilog -o test_8bit BT656_out.v BT656_tb.v
vvp test_8bit

# 10-bit mode test  
iverilog -D BT656_10BIT_MODE -o test_10bit BT656_out.v BT656_tb.v
vvp test_10bit
```

## Implementation Details

### Pixel Counting
- Uses `BT_LINE_LENGTH` parameter for line length
- Supports 1716, 1728, 1560, or 1888 pixels per line
- Automatic wrap-around at line end

### Line Counting
- NTSC: 525 lines per frame
- PAL: 625 lines per frame
- Field division:
  - NTSC: Odd field (1-263), Even field (264-525)
  - PAL: Odd field (1-313), Even field (314-625)

### Clock Domain
- Input clock: Pixel clock frequency
- Output clock: Inverted input clock (CLK_o = ~CLK_i)
- All internal logic synchronized to CLK_i

## File Information

- **Designer**: Konstantin
- **Project**: BT-656 coder, 8/10 bit
- **Tested Platform**: svga050 @olightek
- **Encoding**: UTF-8
- **Timescale**: 1ns/1ps

## Notes

1. For proper operation, select the correct `BT_LINE_LENGTH` for your video standard
2. Ensure pixel clock frequency matches the selected line length
3. In 10-bit mode, input data should be valid 10-bit YCbCr values
4. The module requires external memory/FIFO to provide video data
5. Reset must be asserted before enabling video output

## Compliance

- BT.656 standard for 8-bit mode
- BT.1120 extensions for 10-bit mode
- Supports industry-standard video timing
- Compatible with common video encoders and displays

## Support This Project
If you found this BT.656 encoder implementation useful for your project, research, or product development, please consider giving it a star ⭐.