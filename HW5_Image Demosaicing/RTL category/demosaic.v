module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

parameter IDLE = 0, READ = 1, BILINEAR = 2, FINISH = 3;
reg [2:0] state, next_state;

reg [13:0] count; // 2^14 = 16384
reg [13:0] center;
reg [3:0] i;
reg [13:0] tmp, tmp2;

// state machine
always @(*) begin
    case (state)
        IDLE: next_state <= (in_en)? READ : IDLE;
        READ: next_state <= (count == 16383)? BILINEAR : READ; 
        BILINEAR: next_state <= (center == 16383)? FINISH : BILINEAR;
        FINISH: next_state <= IDLE;
    endcase
end

// logic output
always @(posedge clk)begin
    if(reset)begin 
        state <= IDLE; count <= 0; done <= 1'b0; center <= 0; i <= 0;
    end else begin 
        state <= next_state;
        case(state)
        IDLE: begin
           if(in_en) begin
            done <= 1'b0;
            wr_g <= 1'b1;
            addr_g <= 14'b0;
            wdata_g <= data_in;
            count <= 1;
           end
        end
        READ: begin
            count <= count + 1;
            if(count%2 == 0)begin // even col: g,b
                if(count[13:7]%2==0)begin // even row : g
                    wr_g <= 1'b1;
                    addr_g <= count;
                    wdata_g <= data_in;
                end else begin // odd row: b
                    wr_b <= 1'b1;
                    addr_b <= count;
                    wdata_b <= data_in;
                end
            end else begin // odd col: r,g
                if(count[13:7]%2==0)begin // even row : r
                    wr_r <= 1'b1;
                    addr_r <= count;
                    wdata_r <= data_in;
                end else begin // odd row: g
                    wr_g <= 1'b1;
                    addr_g <= count;
                    wdata_g <= data_in;
                end
            end           
        end
        BILINEAR:begin
            i <= (i + 1)%6;
                case(i)
                    0: begin // read left
                        case({center[7],center[0]})
                            2'b00:begin // left is r
                                wr_r <= 1'b0; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= center - 1;
                            end
                            2'b11:begin // left is b
                                wr_b <= 1'b0; wr_g <= 1'b0; wr_r <= 1'b0;
                                addr_b <= center - 1;
                            end
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= center - 1;
                                addr_r <= center - 129; // left-up
                            end
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= center - 1;
                                addr_b <= center - 129; // left-up
                            end
                        endcase
                    end
                    1:begin // read right and save left
                        case({center[7],center[0]})
                            2'b00:begin // right is r
                                wr_r <= 1'b0; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= center + 1;
                                tmp <= rdata_r;
                            end
                            2'b11:begin // right is b
                                wr_b <= 1'b0; wr_r <= 1'b0; wr_g <= 1'b0;
                                addr_b <= center + 1;
                                tmp <= rdata_b;
                            end
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= center + 1;
                                addr_r <= center - 127; // right-up
                                tmp <= rdata_g;
                                tmp2 <= rdata_r;
                            end
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= center + 1;
                                addr_b <= center - 127; // right-up
                                tmp <= rdata_g;
                                tmp2 <= rdata_b;
                            end
                        endcase
                    end
                    2:begin // write left and right and do bilinear interpolation
                        case({center[7],center[0]})
                            2'b00:begin // right is r
                                wr_r <= 1'b1; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= center;
                                wdata_r <= (rdata_r + tmp) >> 1;
                            end
                            2'b11:begin // right is b
                                wr_b <= 1'b1; wr_g <= 1'b0; wr_r <= 1'b0;
                                addr_b <= center;
                                wdata_b <= (rdata_b + tmp) >> 1;
                            end
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= {center[13:7] - 1, center[6:0]};
                                addr_r <= center + 127; // left-down
                                tmp <= tmp + rdata_g;
                                tmp2 <= tmp2 + rdata_r;
                            end
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= {center[13:7] - 1, center[6:0]};
                                addr_b <= center + 127; // left-down
                                tmp <= tmp + rdata_g;
                                tmp2 <= tmp2 + rdata_b;
                            end
                        endcase                       
                       
                    end
                    3:begin
                        case({center[7],center[0]})
                            2'b00:begin // right is r
                                // read up
                                wr_b <= 1'b0; wr_r <= 1'b0; wr_g <= 1'b0;
                                addr_b <= {center[13:7] - 1, center[6:0]};
                            end
                            2'b11:begin // right is b
                                // read up
                                wr_r <= 1'b0; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= {center[13:7] - 1, center[6:0]};
                            end
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= {center[13:7] + 1, center[6:0]};
                                addr_r <= center + 129; // right-down
                                tmp <= tmp + rdata_g;
                                tmp2 <= tmp2 + rdata_r;
                            end
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b0;
                                addr_g <= {center[13:7] + 1, center[6:0]};
                                addr_b <= center + 129; // right-down
                                tmp <= tmp + rdata_g;
                                tmp2 <= tmp2 + rdata_b;
                            end
                        endcase         
                    end
                    4:begin // read down and save up
                        case({center[7],center[0]})
                            2'b00:begin // right is r
                               wr_b <= 1'b0; wr_r <= 1'b0; wr_g <= 1'b0;
                                addr_b <= {center[13:7] + 1, center[6:0]};
                                tmp <= rdata_b;
                            end
                            2'b11:begin // right is b
                                wr_r <= 1'b0; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= {center[13:7] + 1, center[6:0]};
                                tmp <= rdata_r;
                            end  
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b1; wr_r <= 1'b0; wr_b <= 1'b0; 
                                addr_g <= center;
                                wdata_g <= (rdata_g + tmp) >> 2;
                                tmp2 <= tmp2 + rdata_r;
                            end          
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b1; wr_r <= 1'b0; wr_b <= 1'b0; 
                                addr_g <= center;
                                wdata_g <= (rdata_g + tmp) >> 2;
                                tmp2 <= tmp2 + rdata_b;
                            end
                        endcase
                    end
                    default:begin  // write up and down and do bilinear interpolation
                         case({center[7],center[0]})
                            2'b00:begin // right is r                             
                                wr_b <= 1'b1; wr_r <= 1'b0; wr_g <= 1'b0;
                                addr_b <= center;
                                wdata_b <= (rdata_b + tmp) >> 1;
                            end
                            2'b11:begin // right is b                              
                                wr_r <= 1'b1; wr_g <= 1'b0; wr_b <= 1'b0;
                                addr_r <= center;
                                wdata_r <= (rdata_r + tmp) >> 1;                             
                            end
                            2'b10:begin // left is g left-up is r (center is b)
                                wr_g <= 1'b0; wr_r <= 1'b1; wr_b <= 1'b0;
                                addr_r <= center;
                                wdata_r <= tmp2 >> 2;
                            end
                            default:begin // left is g left-up is b (center is r)
                                wr_g <= 1'b0; wr_r <= 1'b0; wr_b <= 1'b1;
                                addr_b <= center;
                                wdata_b <= tmp2 >> 2;
                            end
                        endcase

                        center <= center + 1;
                    end
                endcase
        end 
        FINISH: done <= 1'b1;
        endcase
    end
end
endmodule

