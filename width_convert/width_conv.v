/* 
 * ----------------------------------------------------------------------------
 *  Project:  Generic
 *  Filename: width_conv.v
 *  Purpose:  High performance up/down width converter.
 * ----------------------------------------------------------------------------
 *  Copyright © 2020-2021, Vaagn Oganesyan <ovgn@protonmail.com>
 *  
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  
 *      http://www.apache.org/licenses/LICENSE-2.0
 *  
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 * ----------------------------------------------------------------------------
 */


module width_conv #
(
    parameter DIN_WIDTH  = 8,
    parameter DOUT_WIDTH = 32
)
(
    input   wire                            clk,
    input   wire                            cen,
    input   wire                            rstn,
    
    input   wire    [DIN_WIDTH - 1:0]       din,
    input   wire    [DIN_WIDTH/8 - 1:0]     din_strb,
    input   wire                            din_last,
    input   wire                            din_valid,
    output  wire                            din_ready,
    
    output  wire    [DOUT_WIDTH - 1:0]      dout,
    output  wire    [DOUT_WIDTH/8 - 1:0]    dout_strb,
    output  wire                            dout_last,
    output  wire                            dout_valid,
    input   wire                            dout_ready
);

/*-------------------------------------------------------------------------------------------------------------------------------------*/

    generate
        if ((DIN_WIDTH  < 1)                                              ||
            (DOUT_WIDTH < 1)                                              ||
            ((DOUT_WIDTH % 8) != 0)                                       ||
            ((DIN_WIDTH % 8)  != 0)                                       ||
            ((DIN_WIDTH > DOUT_WIDTH) && ((DIN_WIDTH % DOUT_WIDTH) != 0)) ||
            ((DIN_WIDTH < DOUT_WIDTH) && ((DOUT_WIDTH % DIN_WIDTH) != 0))) begin
            /* Invalid parameter, force error */
            INVALID_PARAMETER invalid_parameters_msg();
        end
    endgenerate

/*-------------------------------------------------------------------------------------------------------------------------------------*/

    generate
        if (DIN_WIDTH == DOUT_WIDTH) begin  /* Bypass */
            assign dout       = din;
            assign dout_strb  = din_strb;
            assign dout_last  = din_last;
            assign dout_valid = din_valid;
            assign din_ready  = dout_ready;
        end else begin
            if (DIN_WIDTH > DOUT_WIDTH) begin   /* Down conversion */
                
                down_width_conv #
                (
                    .DIN_WIDTH  ( DIN_WIDTH  ),
                    .DOUT_WIDTH ( DOUT_WIDTH )
                )
                down_width_conv_inst
                (
                    .clk        ( clk        ),
                    .cen        ( cen        ),
                    .rstn       ( rstn       ),
                    
                    .din        ( din        ),
                    .din_strb   ( din_strb   ),
                    .din_last   ( din_last   ),
                    .din_valid  ( din_valid  ),
                    .din_ready  ( din_ready  ),
                    
                    .dout       ( dout       ),
                    .dout_strb  ( dout_strb  ),
                    .dout_last  ( dout_last  ),
                    .dout_valid ( dout_valid ),
                    .dout_ready ( dout_ready )
                );
                
            end else begin  /* Up conversion */
            
                up_width_conv #
                (
                    .DIN_WIDTH  ( DIN_WIDTH  ),
                    .DOUT_WIDTH ( DOUT_WIDTH )
                )
                up_width_conv_inst
                (
                    .clk        ( clk        ),
                    .cen        ( cen        ),
                    .rstn       ( rstn       ),
                    
                    .din        ( din        ),
                    .din_strb   ( din_strb   ),
                    .din_last   ( din_last   ),
                    .din_valid  ( din_valid  ),
                    .din_ready  ( din_ready  ),
                    
                    .dout       ( dout       ),
                    .dout_strb  ( dout_strb  ),
                    .dout_last  ( dout_last  ),
                    .dout_valid ( dout_valid ),
                    .dout_ready ( dout_ready )
                );
                
            end
        end
    endgenerate
    
/*-------------------------------------------------------------------------------------------------------------------------------------*/
    
endmodule
