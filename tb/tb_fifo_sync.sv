// ============================================================
//  tb_fifo_sync.sv  —  Directed testbench for fifo_sync
//  Tests: Normal W/R · Full · Overflow · Empty · Underflow
// ============================================================
`timescale 1ns/1ns
module tb_fifo_sync;

    parameter FIFO_DEPTH = 16;
    parameter DATA_WIDTH = 8;

    logic                  clk, rst_n;
    logic                  cs, wr_en, rd_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic                  empty, full;
    logic [7:0] exp_q[$];
    int pass_cnt = 0;
    int fail_cnt = 0;

    fifo_sync #(.FIFO_DEPTH(FIFO_DEPTH),.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk),.rst_n(rst_n),.cs(cs),.wr_en(wr_en),.rd_en(rd_en),
        .data_in(data_in),.data_out(data_out),.empty(empty),.full(full));

    // EPWave dump — must be first initial block
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fifo_sync);
    end

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        cs=0; wr_en=0; rd_en=0; data_in=0; rst_n=0;
        repeat(2) @(posedge clk);
        @(negedge clk); rst_n=1;
    end

    task automatic write_data(input logic [7:0] d);
        logic was_full;
        @(negedge clk);
        was_full = full;
        cs=1; wr_en=1; rd_en=0; data_in=d;
        @(posedge clk); #1;
        if (!was_full && exp_q.size() < FIFO_DEPTH)
            exp_q.push_back(d);
        else
            $display("  WARNING: WRITE IGNORED (full) data=%0d", d);
        @(negedge clk); cs=0; wr_en=0;
    endtask

    task automatic read_data();
        logic [7:0] exp;
        @(negedge clk); cs=1; rd_en=1; wr_en=0;
        @(posedge clk);
        @(negedge clk);
        if (exp_q.size() > 0) begin
            exp = exp_q.pop_front();
            if (data_out !== exp) begin
                $display("  MISMATCH  exp=%0d  got=%0d  time=%0t", exp, data_out, $time);
                fail_cnt++;
            end else begin
                $display("  MATCH     data=%0d  time=%0t", data_out, $time);
                pass_cnt++;
            end
        end else
            $display("  WARNING: UNDERFLOW  time=%0t  empty=%0b", $time, empty);
        cs=0; rd_en=0;
    endtask

    task automatic drain_fifo();
        while (exp_q.size() > 0) read_data();
        @(posedge clk); #1;
    endtask

    task automatic check_full(input string label);
        if (full) $display("  %s: FULL  asserted - PASS", label);
        else      $display("  %s: FULL  NOT set  - FAIL", label);
    endtask

    task automatic check_empty(input string label);
        if (empty) $display("  %s: EMPTY asserted - PASS", label);
        else       $display("  %s: EMPTY NOT set  - FAIL", label);
    endtask

    initial begin
        @(posedge rst_n); repeat(2) @(posedge clk);

        $display("\n=== TEST 1: Normal Write / Read ===");
        write_data(8'd1); write_data(8'd2); write_data(8'd3);
        read_data(); read_data(); read_data();

        $display("\n=== TEST 2: Fill to FULL ===");
        for (int i=0; i<FIFO_DEPTH; i++) write_data(8'(i+10));
        @(posedge clk); #1; check_full("TEST2");

        $display("\n=== TEST 3: Overflow Protection ===");
        write_data(8'hAA); write_data(8'hBB);
        @(posedge clk); #1; check_full("TEST3");
        drain_fifo(); check_empty("TEST3-drain");

        $display("\n=== TEST 4: Drain to EMPTY ===");
        for (int i=0; i<FIFO_DEPTH/2; i++) write_data(8'(i+100));
        drain_fifo(); check_empty("TEST4");

        $display("\n=== TEST 5: Underflow Protection ===");
        read_data(); read_data();
        @(posedge clk); #1; check_empty("TEST5");

        $display("\n=== SUMMARY: PASS=%0d  FAIL=%0d ===\n", pass_cnt, fail_cnt);
        repeat(4) @(posedge clk); $finish;
    end

endmodule
