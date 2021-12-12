/* 
 * ----------------------------------------------------------------------------
 *  Project:  Generic
 *  Filename: up_width_conv.v
 *  Purpose:  High performance up width converter.
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


module up_width_conv #
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
    output  reg                             din_ready,
    
    output  reg     [DOUT_WIDTH - 1:0]      dout,
    output  reg     [DOUT_WIDTH/8 - 1:0]    dout_strb,
    output  reg                             dout_last,
    output  reg                             dout_valid,
    input   wire                            dout_ready
);

/*-------------------------------------------------------------------------------------------------------------------------------------*/

    generate
        if ((DIN_WIDTH  < 1)                ||
            (DOUT_WIDTH < 1)                ||
            ((DOUT_WIDTH % 8) != 0)         ||
            ((DIN_WIDTH  % 8) != 0)         ||
            (DOUT_WIDTH <= DIN_WIDTH)       ||
            ((DOUT_WIDTH % DIN_WIDTH) != 0)) begin
            /* Invalid parameter, force error */
            INVALID_PARAMETER invalid_parameters_msg();
        end
    endgenerate

/*-------------------------------------------------------------------------------------------------------------------------------------*/

    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = 0; 2**i < value; i = i + 1) begin
                clog2 = i + 1;
            end
        end
    endfunction

/*-------------------------------------------------------------------------------------------------------------------------------------*/
    
    localparam  WIDTH_RATIO = DOUT_WIDTH / DIN_WIDTH;
    localparam  DATA_CNT_WIDTH = clog2(WIDTH_RATIO);
    
    
    reg     [DIN_WIDTH - 1:0]       temp_din;
    reg     [DIN_WIDTH/8 - 1:0]     temp_strb;
    reg                             temp_last;
    reg                             temp_valid;
    reg     [DATA_CNT_WIDTH - 1:0]  data_cnt;
    
    wire [3:0] state = { din_valid,  din_ready,  dout_valid,  dout_ready};
    
    
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            dout       <= {DOUT_WIDTH{1'b0}};
            dout_strb  <= {DOUT_WIDTH/8{1'b0}};
            dout_last  <= 1'b0;
            dout_valid <= 1'b0;
            
            temp_din   <= {DOUT_WIDTH{1'b0}};
            temp_strb  <= {DOUT_WIDTH/8{1'b0}};
            temp_last  <= 1'b0;
            temp_valid <= 1'b0;
            
            data_cnt   <= {DATA_CNT_WIDTH{1'b0}};
            din_ready  <= 1'b1;
        end else begin
            if (cen) begin
                case (4'b1111)
                    
                    /* No data under conversion, get ready to accept new word */
                    {~din_valid, ~din_ready, ~dout_valid, ~dout_ready},
                    {~din_valid, ~din_ready, ~dout_valid,  dout_ready},
                    { din_valid, ~din_ready, ~dout_valid, ~dout_ready},
                    { din_valid, ~din_ready, ~dout_valid,  dout_ready}: begin
                        din_ready <= 1'b1;
                    end
                    
                    /* Got new word for conversion */
                    { din_valid,  din_ready, ~dout_valid, ~dout_ready},
                    { din_valid,  din_ready, ~dout_valid,  dout_ready}: begin
                        if (temp_valid) begin
                            temp_valid <= 1'b0;
                            dout[0 +: DIN_WIDTH]        <= temp_din;
                            dout_strb[0 +: DIN_WIDTH/8] <= temp_strb;
                            dout_last                   <= temp_last;
                        end
                        
                        dout[DIN_WIDTH * data_cnt +: DIN_WIDTH] <= din;
                        dout_strb[DIN_WIDTH/8 * data_cnt +: DIN_WIDTH/8] <= din_strb;
                        dout_last  <= din_last;
                        
                        if ((data_cnt == WIDTH_RATIO - 1) || din_last || (temp_valid & temp_last)) begin
                            data_cnt   <= {DATA_CNT_WIDTH{1'b0}};
                            dout_valid <= 1'b1;
                        end else begin
                            data_cnt <= data_cnt + 1'b1;
                        end
                    end
                    
                    /* Waiting for converted data to be sent */
                    {~din_valid, ~din_ready,  dout_valid,  dout_ready},
                    { din_valid, ~din_ready,  dout_valid,  dout_ready},
                    
                    /* Waiting for converted data to be sent and ready for new word */
                    {~din_valid,  din_ready,  dout_valid,  dout_ready}: begin
                        din_ready  <= 1'b1;
                        dout       <= {DOUT_WIDTH{1'b0}};
                        dout_strb  <= {DOUT_WIDTH/8{1'b0}};
                        dout_last  <= 1'b0;
                        dout_valid <= 1'b0;
                    end
                    
                    /* Converted data is not sent yet, but new word should be accepted */
                    { din_valid,  din_ready,  dout_valid, ~dout_ready}: begin
                        temp_din   <= din;
                        temp_strb  <= din_strb;
                        temp_last  <= din_last;
                        temp_valid <= 1'b1;
                        data_cnt   <= 'd1;
                        din_ready  <= 1'b0;
                    end
                    
                     /* Got new word for conversion, while converted data was sent */
                    { din_valid,  din_ready,  dout_valid,  dout_ready}: begin
                        dout       <= {DOUT_WIDTH{1'b0}};
                        dout_strb  <= {DOUT_WIDTH/8{1'b0}};
                        dout_last  <= 1'b0;
                        
                        dout[DIN_WIDTH * data_cnt +: DIN_WIDTH] <= din;
                        dout_strb[DIN_WIDTH/8 * data_cnt +: DIN_WIDTH/8] <= din_strb;
                        dout_last <= din_last;
                        
                        if (~din_last) begin
                            data_cnt   <= 'd1;
                            dout_valid <= 1'b0;
                        end
                    end
                    
                    /* Waiting for converted data to be sent */
                    {~din_valid, ~din_ready,  dout_valid, ~dout_ready},
                    { din_valid, ~din_ready,  dout_valid, ~dout_ready},
                    
                    /* Waiting for converted data to be sent and new incoming word */
                    {~din_valid,  din_ready,  dout_valid, ~dout_ready},
                    
                    /* Waiting for new incoming word */
                    {~din_valid,  din_ready, ~dout_valid, ~dout_ready},
                    {~din_valid,  din_ready, ~dout_valid,  dout_ready}: begin
                        /* Nothing to do */
                    end
                    
                endcase
            end
        end
    end
    
/*-------------------------------------------------------------------------------------------------------------------------------------*/
    
endmodule
