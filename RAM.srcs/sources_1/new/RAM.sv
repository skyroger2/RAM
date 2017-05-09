`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.01.2017 18:31:20
// Design Name: 
// Module Name: RAM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define DEBUG (* keep = "true" *)

module RAM
(
    input       [15:0]  ADDR,
    output  reg [15:0]  DATA_R,
    input       [15:0]  DATA_W,
    input               SYNC,
    input               DIN,
    input               DOUT,
    input               WTBT,
    output  reg         RPLY,
    input               IAKO,
    output  reg         VIRQ = 1,

    input               clk,
    input               rst,

    input       [14:0]  addr2,
    output  reg [15:0]  data2_out,
    input               wr2,
    input               clk2,
    output  reg         ruslat_flag
    );

localparam  RUSLAT          = 16'o42;
localparam  ADDRESS_START   = 16'o0;
localparam  ADDRESS_END     = 16'o077777;

localparam  OVERLAY_START   = 16'o1000;
// localparam  OVERLAY_END     = OVERLAY_START + 1757;
// localparam  OVERLAY_END     = OVERLAY_START + 5139;
localparam  OVERLAY_END     = OVERLAY_START + 10707;

logic   [15:0]  ram_values [16384];
logic           overlay_flag;

//`include    "cputest.vh"
// `include    "Mirage.vh"
`include    "Land.vh"

enum logic [1:0]
{
    MPI_S_FSM_IDLE,
    MPI_S_FSM_ADDRESS_VALIDATED,
    MPI_S_FSM_READ,
    MPI_S_FSM_WRITE
} MPIFSM_currentState, MPIFSM_nextState;

logic   [15:0]  address;
reg     [15:0]  value;
reg     [15:0]  overlay_value;

always_ff @(posedge clk)
    if (!rst)   MPIFSM_currentState <= MPI_S_FSM_IDLE;   
    else        MPIFSM_currentState <= MPIFSM_nextState;

always_comb
    case (MPIFSM_currentState)
    MPI_S_FSM_IDLE: begin
        if (SYNC == 1'b1)           MPIFSM_nextState <= MPI_S_FSM_IDLE;
        else if ((ADDR >= ADDRESS_START) && (ADDR <= ADDRESS_END))
                                    MPIFSM_nextState <= MPI_S_FSM_ADDRESS_VALIDATED;
        else                        MPIFSM_nextState <= MPI_S_FSM_IDLE;
    end

    MPI_S_FSM_ADDRESS_VALIDATED: begin
        if (DIN == 1'b0)            MPIFSM_nextState <= MPI_S_FSM_READ;
        else if (DOUT == 1'b0)      MPIFSM_nextState <= MPI_S_FSM_WRITE;
        else if (SYNC == 1'b1)      MPIFSM_nextState <= MPI_S_FSM_IDLE;
        else                        MPIFSM_nextState <= MPI_S_FSM_ADDRESS_VALIDATED;
    end

    MPI_S_FSM_READ: begin
        if (DIN == 1'b0)            MPIFSM_nextState <= MPI_S_FSM_READ;
        else                        MPIFSM_nextState <= MPI_S_FSM_ADDRESS_VALIDATED;
    end

    MPI_S_FSM_WRITE: begin
        if (DOUT == 1'b0)           MPIFSM_nextState <= MPI_S_FSM_WRITE;
        else                        MPIFSM_nextState <= MPI_S_FSM_ADDRESS_VALIDATED;
    end

    default:                        MPIFSM_nextState <= MPI_S_FSM_IDLE;
    endcase

always_ff @(posedge clk)
begin
    if (MPIFSM_currentState == MPI_S_FSM_IDLE) begin
        if (SYNC == 1'b0)           address <= ADDR;
        RPLY <= 1'b1;
        overlay_flag <= ((ADDR >= OVERLAY_START) && (ADDR <= OVERLAY_END)) ? 1 : 0;
    end
    else if (MPIFSM_currentState == MPI_S_FSM_WRITE) begin
        if (DOUT == 1'b0)
            if (overlay_flag == 0)
            if (WTBT == 1'b1) begin
                if (address[0:0] == 1'b0)       ram_values[address >> 1][7:0]   <= DATA_W[7:0];
                else                            ram_values[address >> 1][15:8]  <= DATA_W[15:8];

                if ({address[15:1], 1'b0} == RUSLAT)
                    if (address[0:0] == 1'b0)   ;
                    else                        ruslat_flag  <= DATA_W[15];

            end
            else begin
                                                ram_values[address >> 1]        <= DATA_W;
                if (address == RUSLAT)          ruslat_flag <= DATA_W[15];
            end

            else

            if (WTBT == 1'b1) begin
                if (address[0:0] == 1'b0)       overlayedvalues[(address - OVERLAY_START) >> 1][7:0]   <= DATA_W[7:0];
                else                            overlayedvalues[(address - OVERLAY_START) >> 1][15:8]  <= DATA_W[15:8];
            end
            else begin
                                                overlayedvalues[(address - OVERLAY_START) >> 1]        <= DATA_W;
            end


            RPLY <= 1'b0;
    end
    else if (MPIFSM_currentState == MPI_S_FSM_ADDRESS_VALIDATED) begin
        RPLY <= 1'b1;
    end

    if (MPIFSM_currentState == MPI_S_FSM_READ) begin
        RPLY <= 1'b0;
    end
    value <= ram_values[address >> 1];
    overlay_value <= overlayedvalues[(address - OVERLAY_START) >> 1];
end

assign  DATA_R = (MPIFSM_currentState == MPI_S_FSM_READ) ? ((overlay_flag == 0) ? value : overlay_value) : 16'hFFFF;

always_ff @(posedge clk2)
    if (wr2 == 0)   data2_out <= ram_values[addr2 >> 1];
//    else            ram_values[addr2 >> 1] <= data_in;
endmodule
