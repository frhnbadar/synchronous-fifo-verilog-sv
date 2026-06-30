module fifo_sync #(
    parameter FIFO_DEPTH = 16,
    parameter DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  cs,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  empty,
    output logic                  full
);
    // One extra bit in the pointer catches wrap-around
    localparam ADDR = $clog2(FIFO_DEPTH);

    logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH];
    logic [ADDR:0]         wr_ptr, rd_ptr;

    // ----------------------------------------------------------------
    // WRITE  (registered)
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (cs && wr_en && !full) begin
            mem[wr_ptr[ADDR-1:0]] <= data_in;
            wr_ptr                <= wr_ptr + 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // READ  (registered – data_out is valid ONE cycle after rd_en)
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= '0;
            data_out <= '0;
        end
        else if (cs && rd_en && !empty) begin
            data_out <= mem[rd_ptr[ADDR-1:0]];
            rd_ptr   <= rd_ptr + 1'b1;
        end
    end

    // ----------------------------------------------------------------
    //   empty : pointers identical
    //   full  : MSBs differ, lower bits identical  
    // ----------------------------------------------------------------
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR]     != rd_ptr[ADDR]) &&
                   (wr_ptr[ADDR-1:0] == rd_ptr[ADDR-1:0]);

endmodule