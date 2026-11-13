`timescale 1ns / 1ps

module mac_unit #(
    parameter int DATA_W = 8,
    parameter int PROD_W = 16
)(
    input  logic signed [8:0][DATA_W-1:0] win_in,
    input  logic signed [8:0][DATA_W-1:0] weight_in,
    output logic signed [8:0][PROD_W-1:0] prod_out
);

    genvar k;
    generate
        for (k = 0; k < 9; k++) begin : gen_mult
            assign prod_out[k] = PROD_W'(signed'(win_in[k])) * PROD_W'(signed'(weight_in[k]));
        end
    endgenerate

endmodule