// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module ArbitrationTree_L2
#(
   parameter ADDR_WIDTH = 12,
   parameter DATA_WIDTH = 64,
   parameter BYTE_NUM   = DATA_WIDTH/8,
   parameter BE_WIDTH   = BYTE_NUM,
   parameter TAG_WIDTH  = BYTE_NUM,
   parameter ID_WIDTH   = 20,
   parameter N_MASTER   = 16,
   parameter MAX_COUNT  = N_MASTER
)
(
   input  logic                                      clk,
   input  logic                                      rst_n,

   // ---------------- REQ_SIDE --------------------------
   input  logic [N_MASTER-1:0]                       data_req_i,
   input  logic [N_MASTER-1:0][ADDR_WIDTH-1:0]       data_add_i,
   input  logic [N_MASTER-1:0]                       data_wen_i,
   input  logic [N_MASTER-1:0][DATA_WIDTH-1:0]       data_wdata_i,
   input  logic [N_MASTER-1:0][TAG_WIDTH-1:0]        data_wtag_i,
   input  logic [N_MASTER-1:0][BE_WIDTH-1:0]         data_be_i,
   input  logic [N_MASTER-1:0][ID_WIDTH-1:0]         data_ID_i,
   output logic [N_MASTER-1:0]                       data_gnt_o,

   // Outputs
   output logic                                      data_req_o,
   output logic [ADDR_WIDTH-1:0]                     data_add_o,
   output logic                                      data_wen_o,
   output logic [DATA_WIDTH-1:0]                     data_wdata_o,
   output logic [TAG_WIDTH-1:0]                      data_wtag_o,
   output logic [BE_WIDTH-1:0]                       data_be_o,
   output logic [ID_WIDTH-1:0]                       data_ID_o,
   input  logic                                      data_gnt_i
);

    localparam LOG_MASTER       = $clog2(N_MASTER);
    localparam N_WIRE           = N_MASTER - 2;

    logic [LOG_MASTER-1:0]      RR_FLAG;

    genvar j,k;


    generate
      if(N_MASTER == 2)
        begin : INCR // START of  MASTER  == 2
                     // ---------------- FAN IN PRIMITIVE  -------------------------
                     FanInPrimitive_Req_L2
                     #(
                        .ADDR_WIDTH ( ADDR_WIDTH ),
                        .ID_WIDTH   ( ID_WIDTH   ),
                        .DATA_WIDTH ( DATA_WIDTH ),
                        .BE_WIDTH   ( BE_WIDTH   ),
                        .TAG_WIDTH  ( TAG_WIDTH  )
                     )
                     FAN_IN_REQ
                     (
                        .RR_FLAG       ( RR_FLAG         ),
                        // LEFT SIDE"
                        .data_wdata0_i ( data_wdata_i[0] ),
                        .data_wdata1_i ( data_wdata_i[1] ),
                        .data_wtag0_i  ( data_wtag_i [0] ),
                        .data_wtag1_i  ( data_wtag_i [1] ),
                        .data_add0_i   ( data_add_i  [0] ),
                        .data_add1_i   ( data_add_i  [1] ),
                        .data_req0_i   ( data_req_i  [0] ),
                        .data_req1_i   ( data_req_i  [1] ),
                        .data_wen0_i   ( data_wen_i  [0] ),
                        .data_wen1_i   ( data_wen_i  [1] ),
                        .data_ID0_i    ( data_ID_i   [0] ),
                        .data_ID1_i    ( data_ID_i   [1] ),
                        .data_be0_i    ( data_be_i   [0] ),
                        .data_be1_i    ( data_be_i   [1] ),

                        .data_gnt0_o   ( data_gnt_o  [0] ),
                        .data_gnt1_o   ( data_gnt_o  [1] ),

                        // RIGTH SIDE"
                        .data_wdata_o  ( data_wdata_o    ),
                        .data_wtag_o   ( data_wtag_o     ),
                        .data_add_o    ( data_add_o      ),
                        .data_req_o    ( data_req_o      ),
                        .data_wen_o    ( data_wen_o      ),
                        .data_ID_o     ( data_ID_o       ),
                        .data_be_o     ( data_be_o       ),
                        .data_gnt_i    ( data_gnt_i      )
                     );
        end // END OF MASTER  == 2
      else // More than two master
        begin : BINARY_TREE
            //// ---------------------------------------------------------------------- ////
            //// -------               REQ ARBITRATION TREE WIRES           ----------- ////
            //// ---------------------------------------------------------------------- ////
            logic [DATA_WIDTH-1:0]              data_wdata_LEVEL[N_WIRE-1:0];
            logic [TAG_WIDTH-1:0]               data_wtag_LEVEL[N_WIRE-1:0];
            logic [ADDR_WIDTH-1:0]              data_add_LEVEL[N_WIRE-1:0];
            logic                               data_req_LEVEL[N_WIRE-1:0];
            logic                               data_wen_LEVEL[N_WIRE-1:0];
            logic [ID_WIDTH-1:0]                data_ID_LEVEL[N_WIRE-1:0];
            logic [BE_WIDTH-1:0]                data_be_LEVEL[N_WIRE-1:0];
            logic                               data_gnt_LEVEL[N_WIRE-1:0];



              for(j=0; j < LOG_MASTER; j++) // Iteration for the number of the stages minus one
                begin : STAGE
                  for(k=0; k<2**j; k=k+1) // Iteration needed to create the binary tree
                    begin : INCR_VERT

                      if (j == 0 )  // LAST NODE, drives the module outputs
                      begin : LAST_NODE
                          FanInPrimitive_Req_L2
                          #(
                              .ADDR_WIDTH  ( ADDR_WIDTH   ),
                              .ID_WIDTH    ( ID_WIDTH     ),
                              .DATA_WIDTH  ( DATA_WIDTH   ),
                              .BE_WIDTH    ( BE_WIDTH     ),
                              .TAG_WIDTH   ( TAG_WIDTH    )
                          )
                          FAN_IN_REQ
                          (
                             .RR_FLAG(RR_FLAG[LOG_MASTER-j-1]),
                             // LEFT SIDE
                             .data_wdata0_i ( data_wdata_LEVEL [2*k]   ),
                             .data_wdata1_i ( data_wdata_LEVEL [2*k+1] ),
                             .data_wtag0_i  ( data_wtag_LEVEL [2*k]    ),
                             .data_wtag1_i  ( data_wtag_LEVEL [2*k+1]  ),
                             .data_add0_i   ( data_add_LEVEL   [2*k]   ),
                             .data_add1_i   ( data_add_LEVEL   [2*k+1] ),
                             .data_req0_i   ( data_req_LEVEL   [2*k]   ),
                             .data_req1_i   ( data_req_LEVEL   [2*k+1] ),
                             .data_wen0_i   ( data_wen_LEVEL   [2*k]   ),
                             .data_wen1_i   ( data_wen_LEVEL   [2*k+1] ),
                             .data_ID0_i    ( data_ID_LEVEL    [2*k]   ),
                             .data_ID1_i    ( data_ID_LEVEL    [2*k+1] ),
                             .data_be0_i    ( data_be_LEVEL    [2*k]   ),
                             .data_be1_i    ( data_be_LEVEL    [2*k+1] ),
                             .data_gnt0_o   ( data_gnt_LEVEL   [2*k]   ),
                             .data_gnt1_o   ( data_gnt_LEVEL   [2*k+1] ),
                             // RIGTH SIDE
                             .data_wdata_o  ( data_wdata_o             ),
                             .data_wtag_o   ( data_wtag_o              ),
                             .data_add_o    ( data_add_o               ),
                             .data_req_o    ( data_req_o               ),
                             .data_wen_o    ( data_wen_o               ),
                             .data_ID_o     ( data_ID_o                ),
                             .data_be_o     ( data_be_o                ),
                             .data_gnt_i    ( data_gnt_i               )
                          );
                      end
                      else if ( j < LOG_MASTER - 1) // Middle Nodes
                              begin : MIDDLE_NODES // START of MIDDLE LEVELS Nodes
                                  FanInPrimitive_Req_L2
                                  #(
                                    .ADDR_WIDTH ( ADDR_WIDTH ),
                                    .ID_WIDTH   ( ID_WIDTH   ),
                                    .DATA_WIDTH ( DATA_WIDTH ),
                                    .BE_WIDTH   ( BE_WIDTH   ),
                                    .TAG_WIDTH  ( TAG_WIDTH  )
                                  )
                                  FAN_IN_REQ
                                  (
                                    .RR_FLAG       ( RR_FLAG[LOG_MASTER-j-1]                  ),
                                    // LEFT SIDE
                                    .data_wdata0_i ( data_wdata_LEVEL [((2**j)*2-2) + 2*k]    ),
                                    .data_wdata1_i ( data_wdata_LEVEL [((2**j)*2-2) + 2*k+1]  ),
                                    .data_wtag0_i  ( data_wtag_LEVEL  [((2**j)*2-2) + 2*k]    ),
                                    .data_wtag1_i  ( data_wtag_LEVEL  [((2**j)*2-2) + 2*k+1]  ),
                                    .data_add0_i   ( data_add_LEVEL   [((2**j)*2-2) + 2*k]    ),
                                    .data_add1_i   ( data_add_LEVEL   [((2**j)*2-2) + 2*k+1]  ),
                                    .data_req0_i   ( data_req_LEVEL   [((2**j)*2-2) + 2*k]    ),
                                    .data_req1_i   ( data_req_LEVEL   [((2**j)*2-2) + 2*k+1]  ),
                                    .data_wen0_i   ( data_wen_LEVEL   [((2**j)*2-2) + 2*k]    ),
                                    .data_wen1_i   ( data_wen_LEVEL   [((2**j)*2-2) + 2*k+1]  ),
                                    .data_ID0_i    ( data_ID_LEVEL    [((2**j)*2-2) + 2*k]    ),
                                    .data_ID1_i    ( data_ID_LEVEL    [((2**j)*2-2) + 2*k+1]  ),
                                    .data_be0_i    ( data_be_LEVEL    [((2**j)*2-2) + 2*k]    ),
                                    .data_be1_i    ( data_be_LEVEL    [((2**j)*2-2) + 2*k+1]  ),
                                    .data_gnt0_o   ( data_gnt_LEVEL   [((2**j)*2-2) + 2*k]    ),
                                    .data_gnt1_o   ( data_gnt_LEVEL   [((2**j)*2-2) + 2*k+1]  ),


                                    // RIGTH SIDE
                                    .data_wdata_o ( data_wdata_LEVEL [((2**(j-1))*2-2) + k]  ),
                                    .data_wtag_o  ( data_wtag_LEVEL  [((2**(j-1))*2-2) + k]  ),
                                    .data_add_o   ( data_add_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                    .data_req_o   ( data_req_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                    .data_wen_o   ( data_wen_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                    .data_ID_o    ( data_ID_LEVEL    [((2**(j-1))*2-2) + k]  ),
                                    .data_be_o    ( data_be_LEVEL    [((2**(j-1))*2-2) + k]  ),
                                    .data_gnt_i   ( data_gnt_LEVEL   [((2**(j-1))*2-2) + k]  )
                                  );
                              end  // END of MIDDLE LEVELS Nodes
                           else // First stage (connected with the Main inputs ) --> ( j == N_MASTER - 1 )
                              begin : LEAF_NODES  // START of FIRST LEVEL Nodes (LEAF)
                                  FanInPrimitive_Req_L2
                                  #(
                                    .ADDR_WIDTH ( ADDR_WIDTH ),
                                    .ID_WIDTH   ( ID_WIDTH   ),
                                    .DATA_WIDTH ( DATA_WIDTH ),
                                    .BE_WIDTH   ( BE_WIDTH   ),
                                    .TAG_WIDTH  ( TAG_WIDTH  )
                                  )
                                  FAN_IN_REQ
                                  (
                                     .RR_FLAG        ( RR_FLAG[LOG_MASTER-j-1]                 ),
                                     // LEFT SIDE
                                     .data_wdata0_i  ( data_wdata_i [2*k]                      ),
                                     .data_wdata1_i  ( data_wdata_i [2*k+1]                    ),
                                     .data_wtag0_i   ( data_wtag_i [2*k]                       ),
                                     .data_wtag1_i   ( data_wtag_i [2*k+1]                     ),
                                     .data_add0_i    ( data_add_i   [2*k]                      ),
                                     .data_add1_i    ( data_add_i   [2*k+1]                    ),
                                     .data_req0_i    ( data_req_i   [2*k]                      ),
                                     .data_req1_i    ( data_req_i   [2*k+1]                    ),
                                     .data_wen0_i    ( data_wen_i   [2*k]                      ),
                                     .data_wen1_i    ( data_wen_i   [2*k+1]                    ),
                                     .data_ID0_i     ( data_ID_i    [2*k]                      ),
                                     .data_ID1_i     ( data_ID_i    [2*k+1]                    ),
                                     .data_be0_i     ( data_be_i    [2*k]                      ),
                                     .data_be1_i     ( data_be_i    [2*k+1]                    ),
                                     .data_gnt0_o    ( data_gnt_o   [2*k]                      ),
                                     .data_gnt1_o    ( data_gnt_o   [2*k+1]                    ),

                                     // RIGTH SIDE
                                     .data_wdata_o  ( data_wdata_LEVEL [((2**(j-1))*2-2) + k]  ),
                                     .data_wtag_o   ( data_wtag_LEVEL [((2**(j-1))*2-2) + k]   ),
                                     .data_add_o    ( data_add_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                     .data_req_o    ( data_req_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                     .data_wen_o    ( data_wen_LEVEL   [((2**(j-1))*2-2) + k]  ),
                                     .data_ID_o     ( data_ID_LEVEL    [((2**(j-1))*2-2) + k]  ),
                                     .data_be_o     ( data_be_LEVEL    [((2**(j-1))*2-2) + k]  ),
                                     .data_gnt_i    ( data_gnt_LEVEL   [((2**(j-1))*2-2) + k]  )
                                  );
                              end // End of FIRST LEVEL Nodes (LEAF)
                    end

                end

    end
    endgenerate


    //COUNTER USED TO SWITCH PERIODICALLY THE PRIORITY FLAG"
    RR_Flag_Req_L2
    #(
      .WIDTH     ( LOG_MASTER ),
      .MAX_COUNT ( MAX_COUNT  )
    )
    RR_REQ
    (
        .clk        ( clk        ),
        .rst_n      ( rst_n      ),
        .RR_FLAG_o  ( RR_FLAG    ),
        .data_req_i ( data_req_o ),
        .data_gnt_i ( data_gnt_i )
    );


endmodule
