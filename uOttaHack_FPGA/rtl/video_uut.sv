/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack-a-Thon 2026
DESCRIPTION  :  Two sprites collide and reveal "UOTTAHACK 8" letter by letter
****************************************************************************/

module video_uut (
    input  wire         clk_i,
    input  wire         cen_i,
    input  wire         rst_i,
    input  wire         vid_sel_i,
    input  wire [23:0]  vid_rgb_i,
    input  wire [1:0]   vh_blank_i,
    input  wire [2:0]   dvh_sync_i,
    output wire [2:0]   dvh_sync_o,
    output wire [23:0]  vid_rgb_o
);

    // =========================================================
    // CONSTANTS
    // =========================================================
    localparam [23:0] RGB_COLOUR = 24'h008080; // Dark cyan background
    localparam int H_ACTIVE = 1920;
    localparam int V_ACTIVE = 1080;

    // Sprite parameters
    localparam int SPR_W = 128;
    localparam int SPR_H = 128;
    localparam int SCALE = 2;
    localparam int SPR_W_SCALED = SPR_W * SCALE;
    localparam int SPR_H_SCALED = SPR_H * SCALE;

    // Letters
    localparam int TEXT_LEN = 11; // "UOTTAHACK 8"
    localparam int LETTER_W = 32;  // Width of each letter sprite
    localparam int LETTER_H = 32;  // Height of each letter sprite
    localparam int LETTER_SCALE = 4; // Scale letters 3x bigger

    // =========================================================
    // PIPELINE REGISTERS
    // =========================================================
    reg [23:0] vid_rgb_d1;
    reg [2:0]  dvh_sync_d1;

    // =========================================================
    // SYNC INPUTS
    // =========================================================
    wire de_in    = dvh_sync_i[2];
    wire vsync_in = dvh_sync_i[1];
    wire hsync_in = dvh_sync_i[0];

    reg hsync_d, vsync_d;
    wire hsync_rise = hsync_in && !hsync_d;
    wire vsync_rise = vsync_in && !vsync_d;

    // =========================================================
    // PIXEL COUNTERS
    // =========================================================
    reg [10:0] x_cnt;
    reg [10:0] y_cnt;

    // =========================================================
    // SPRITE A (left → middle)
    // =========================================================
    reg [10:0] x_A;
    reg [10:0] y_A;
    reg [23:0] sprite_A [0:SPR_W*SPR_H-1];
    initial $readmemh("sprite.hex", sprite_A);

    // =========================================================
    // SPRITE B (right → middle)
    // =========================================================
    reg [10:0] x_B;
    reg [10:0] y_B;
    reg [23:0] sprite_B [0:SPR_W*SPR_H-1];
    initial $readmemh("sprite.hex", sprite_B);

    // =========================================================
    // LETTERS HEX
    // =========================================================
    reg [23:0] letter_U [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_O [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_T [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_T2[0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_A [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_H [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_A2[0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_C [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_K [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_space [0:LETTER_W*LETTER_H-1];
    reg [23:0] letter_8 [0:LETTER_W*LETTER_H-1];
    
    initial begin
        $readmemh("U.hex",    letter_U);
        $readmemh("O.hex",    letter_O);
        $readmemh("T.hex",    letter_T);
        $readmemh("T2.hex",   letter_T2);
        $readmemh("A.hex",    letter_A);
        $readmemh("H.hex",    letter_H);
        $readmemh("A2.hex",   letter_A2);
        $readmemh("C.hex",    letter_C);
        $readmemh("K.hex",    letter_K);
        $readmemh("space.hex",letter_space);
        $readmemh("8.hex",    letter_8);
    end

    // =========================================================
    // COLLISION FLAG & SPRITE VISIBILITY
    // =========================================================
    reg collision_reg;
    reg sprites_visible;

    wire collision_detect = (x_A + SPR_W_SCALED - 20 >= x_B + 20) &&
                            (x_A + 20 <= x_B + SPR_W_SCALED - 20);

    // =========================================================
    // LETTER REVEAL CONTROL - FASTER!
    // =========================================================
    reg [3:0] current_letter;  // 0..10
    reg [15:0] letter_counter;

    // =========================================================
    // LETTER POSITION CALCULATION
    // =========================================================
    wire [10:0] letter_scaled_width = LETTER_W * LETTER_SCALE;
    wire [10:0] letter_scaled_height = LETTER_H * LETTER_SCALE;
    wire [10:0] letter_start_x = (H_ACTIVE - letter_scaled_width*TEXT_LEN)/2;
    wire [10:0] letter_start_y = V_ACTIVE/2 - letter_scaled_height/2;
    
    // =========================================================
    // SPRITE PIXEL CALCULATIONS
    // =========================================================
    wire inside_A = (x_cnt >= x_A && x_cnt < x_A + SPR_W_SCALED) &&
                    (y_cnt >= y_A && y_cnt < y_A + SPR_H_SCALED);
    wire [6:0] a_x = (x_cnt - x_A)/SCALE;
    wire [6:0] a_y = (y_cnt - y_A)/SCALE;
    wire [13:0] a_addr = a_y*SPR_W + a_x;
    wire [23:0] pixel_A = sprite_A[a_addr];
    wire a_transp = (pixel_A == 24'hFF00FF);

    wire inside_B = (x_cnt >= x_B && x_cnt < x_B + SPR_W_SCALED) &&
                    (y_cnt >= y_B && y_cnt < y_B + SPR_H_SCALED);
    wire [6:0] b_x = (x_cnt - x_B)/SCALE;
    wire [6:0] b_y = (y_cnt - y_B)/SCALE;
    wire [13:0] b_addr = b_y*SPR_W + b_x;
    wire [23:0] pixel_B = sprite_B[b_addr];
    wire b_transp = (pixel_B == 24'hFF00FF);

    // =========================================================
    // LETTER PIXEL SELECTION (combinational)
    // =========================================================
    reg [23:0] letter_pixel;
    reg letter_active;
    
    always @(*) begin
        letter_pixel = 24'hFF00FF; // Default transparent
        letter_active = 0;
        
        // Check each revealed letter
        for (int i = 0; i < TEXT_LEN; i = i + 1) begin
            if (i < current_letter) begin
                // Check if pixel is within this letter's SCALED bounds
                if ((x_cnt >= letter_start_x + i*letter_scaled_width) &&
                    (x_cnt < letter_start_x + (i+1)*letter_scaled_width) &&
                    (y_cnt >= letter_start_y) &&
                    (y_cnt < letter_start_y + letter_scaled_height)) begin
                    
                    // Calculate pixel coordinates within letter (with scaling)
                    reg [5:0] lx;    
                    reg [5:0] ly;    
                    reg [11:0] letter_addr;
                    
                    // Scale down to original letter size
                    lx = (x_cnt - letter_start_x - i*letter_scaled_width) / LETTER_SCALE;
                    ly = (y_cnt - letter_start_y) / LETTER_SCALE;
                    
                    // Check bounds (important for scaling)
                    if (lx < LETTER_W && ly < LETTER_H) begin
                        letter_addr = ly * LETTER_W + lx;
                        
                        // Get pixel from appropriate letter ROM
                        case (i)
                            0: letter_pixel = letter_U[letter_addr];
                            1: letter_pixel = letter_O[letter_addr];
                            2: letter_pixel = letter_T[letter_addr];
                            3: letter_pixel = letter_T2[letter_addr];
                            4: letter_pixel = letter_A[letter_addr];
                            5: letter_pixel = letter_H[letter_addr];
                            6: letter_pixel = letter_A2[letter_addr];
                            7: letter_pixel = letter_C[letter_addr];
                            8: letter_pixel = letter_K[letter_addr];
                            9: letter_pixel = letter_space[letter_addr];
                            10: letter_pixel = letter_8[letter_addr];
                            default: letter_pixel = 24'hFF00FF;
                        endcase
                        
                        letter_active = 1;
                    end
                    break; // Stop checking other letters
                end
            end
        end
    end
    
    wire letter_transparent = (letter_pixel == 24'hFF00FF);

    // =========================================================
    // MAIN SEQUENTIAL LOGIC
    // =========================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            x_cnt <= 0;
            y_cnt <= 0;
            hsync_d <= 0;
            vsync_d <= 0;

            x_A <= 0;
            y_A <= V_ACTIVE/2 - SPR_H_SCALED/2;

            x_B <= H_ACTIVE - SPR_W_SCALED;
            y_B <= V_ACTIVE/2 - SPR_H_SCALED/2;

            collision_reg <= 0;
            sprites_visible <= 1;  // Sprites start visible
            current_letter <= 0;
            letter_counter <= 0;

            vid_rgb_d1 <= 0;
            dvh_sync_d1 <= 0;

        end else if (cen_i) begin
            hsync_d <= hsync_in;
            vsync_d <= vsync_in;

            // Pixel counters
            if (vsync_rise) begin
                x_cnt <= 0;
                y_cnt <= 0;
            end else if (hsync_rise) begin
                x_cnt <= 0;
                if (y_cnt != V_ACTIVE-1) y_cnt <= y_cnt + 1;
            end else if (de_in) begin
                if (x_cnt != H_ACTIVE-1) x_cnt <= x_cnt + 1;
            end

            // Sprite movement until collision
            if (!collision_reg && vsync_rise) begin
                if (x_A + SPR_W_SCALED < H_ACTIVE/2 + SPR_W_SCALED/2)
                    x_A <= x_A + 3;
                if (x_B > H_ACTIVE/2 - SPR_W_SCALED/2)
                    x_B <= x_B - 3;

                if (collision_detect) begin
                    collision_reg <= 1;
                    sprites_visible <= 0;  // Hide sprites on collision!
                end
            end

            // Reveal letters one by one after collision - MUCH FASTER!
            if (collision_reg && vsync_rise) begin
                // Changed from 100 to 5 frames - 12x faster!
                if (letter_counter == 5) begin // FAST reveal - 5 frames per letter
                    if (current_letter < TEXT_LEN)
                        current_letter <= current_letter + 1;
                    letter_counter <= 0;
                end else
                    letter_counter <= letter_counter + 1;
            end
            
            // =========================================================
            // FINAL PIXEL MUX (synchronous) - ALWAYS USE DARK CYAN
            // =========================================================
            if (sprites_visible && !collision_reg) begin
                // Show sprites before collision
                if (inside_A && !a_transp)
                    vid_rgb_d1 <= pixel_A;
                else if (inside_B && !b_transp)
                    vid_rgb_d1 <= pixel_B;
                else
                    vid_rgb_d1 <= RGB_COLOUR; // Always dark cyan background
            end else begin
                // After collision → show letters
                if (letter_active && !letter_transparent)
                    vid_rgb_d1 <= letter_pixel;
                else
                    vid_rgb_d1 <= RGB_COLOUR; // Always dark cyan background
            end
            
            dvh_sync_d1 <= dvh_sync_i;
        end
    end

    assign dvh_sync_o = dvh_sync_d1;
    assign vid_rgb_o  = vid_rgb_d1;

endmodule