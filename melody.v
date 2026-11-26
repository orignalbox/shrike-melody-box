(* top *) module melody (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,
    (* iopad_external_pin *) input  btn_n,
    (* iopad_external_pin *) output piezo_p,
    (* iopad_external_pin *) output piezo_p_en,
    (* iopad_external_pin *) output piezo_n,
    (* iopad_external_pin *) output piezo_n_en,
    (* iopad_external_pin *) output clk_en
);
    assign clk_en     = 1'b1;
    assign piezo_p_en = 1'b1;
    assign piezo_n_en = 1'b1;

    // half-period in clocks at 50 MHz = 25,000,000 / note frequency
    localparam REST = 16'd0,
               C5 = 16'd47801, D5 = 16'd42589, E5 = 16'd37936,
               F5 = 16'd35816, G5 = 16'd31888, A5 = 16'd28409,
               C6 = 16'd23878, E6 = 16'd18954, G6 = 16'd15944;

    // button toggles the song (debounced)
    reg        song = 1'b0;
    reg [19:0] db = 20'd0;
    reg        prev = 1'b1;
    always @(posedge clk) begin
        db <= db + 1'b1;
        if (db == 20'd0) begin
            if (prev && !btn_n) song <= ~song;
            prev <= btn_n;
        end
    end

    // one note step every 2^23 clocks (about 168 ms)
    reg [22:0] tick_div = 23'd0;
    reg [3:0]  idx = 4'd0;
    wire       tick = (tick_div == 23'd0);
    always @(posedge clk) begin
        tick_div <= tick_div + 1'b1;
        if (tick) idx <= idx + 1'b1;
    end

    // melody lookup table
    reg [15:0] half;
    always @(*) begin
        case ({song, idx})
            // song 0: ode to joy (opening)
            5'd0:  half = E5;   5'd1:  half = E5;   5'd2:  half = F5;   5'd3:  half = G5;
            5'd4:  half = G5;   5'd5:  half = F5;   5'd6:  half = E5;   5'd7:  half = D5;
            5'd8:  half = C5;   5'd9:  half = C5;   5'd10: half = D5;   5'd11: half = E5;
            5'd12: half = E5;   5'd13: half = D5;   5'd14: half = D5;   5'd15: half = REST;
            // song 1: c major arpeggio up and down
            5'd16: half = C5;   5'd17: half = E5;   5'd18: half = G5;   5'd19: half = C6;
            5'd20: half = E6;   5'd21: half = G6;   5'd22: half = E6;   5'd23: half = C6;
            5'd24: half = G5;   5'd25: half = E5;   5'd26: half = C5;   5'd27: half = E5;
            5'd28: half = G5;   5'd29: half = C6;   5'd30: half = G5;   5'd31: half = REST;
            default: half = REST;
        endcase
    end

    // square wave at the note frequency
    reg [15:0] cnt = 16'd0;
    reg        sq = 1'b0;
    always @(posedge clk) begin
        if (half == 16'd0) begin
            cnt <= 16'd0;
            sq  <= 1'b0;
        end else if (cnt >= half) begin
            cnt <= 16'd0;
            sq  <= ~sq;
        end else
            cnt <= cnt + 1'b1;
    end

    // pluck envelope: restarts every note, fades out; pwm gates the tone
    reg [14:0] env_div = 15'd0;
    reg [7:0]  env = 8'd0;
    reg [7:0]  pwm = 8'd0;
    always @(posedge clk) begin
        env_div <= env_div + 1'b1;
        pwm     <= pwm + 1'b1;
        if (tick) env <= 8'd255;
        else if (env_div == 15'd0 && env != 8'd0) env <= env - 1'b1;
    end

    wire active = (half != 16'd0) && (pwm < env);
    assign piezo_p = active &  sq;
    assign piezo_n = active & ~sq;
endmodule
