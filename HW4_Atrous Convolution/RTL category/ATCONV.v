`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,
	
	output reg 	csel
	);

// state setting
parameter IDLE = 0, LAYER_0 = 1, LAYER_1 = 2, FINISH = 3;
reg [2:0] state, next_state;
reg [12:0] i; // record pixel
reg [12:0] conv_temp [0:1];
reg [12:0] bias;
reg [13:0] cnt;
reg [2:0] j; // layer 1
reg [13:0] max_value = 0;
reg [10:0] current = 0;
reg [10:0] address = 0;
 
wire cmp = cdata_rd > max_value;

// state machine
always @(*) begin
	case(state)
		IDLE:begin
			if (ready) begin
				next_state <= LAYER_0;
			end else begin
				next_state <= IDLE;
			end
		end
		LAYER_0:begin
			if (i == 4096)begin // do 256 pixels
				next_state <= LAYER_1;
			end else begin
				next_state <= LAYER_0;
			end
		end
		LAYER_1:begin
			if(address == 1024)begin
				next_state <= FINISH;
			end else begin
				next_state <= LAYER_1;
			end		
		end
		default:begin
			next_state <= IDLE;
		end
	endcase
end

// logic output
always @(posedge clk) begin
	if (reset) begin
		state <= IDLE; i <= 0; bias <= 13'h1ff4; cnt <= 0; j <= 0;
	end else begin
		state <= next_state;
		case(state)
		IDLE:begin
			if(ready)begin
				busy <= 1'b1; csel <= 0;  cnt <= 0;  cwr <= 1; 
				conv_temp[0] <= 0; conv_temp[1] <= 0; 
			end else begin
			end
		end
		LAYER_0:begin
			if(cnt == 0)begin // X0
				if(i % 64 == 0 || i % 64 == 1)begin // padding case
					if(i < 130)begin 
						iaddr <= 0;
					end else begin
						iaddr <= (i >> 6 << 6) - 128;
					end	
				end else begin
					if(i < 130)begin // padding case
						iaddr <= i - 2 - (i >> 6 << 6) ; // else
					end else begin
						iaddr <= i - 130 ; // else
					end					
				end
			end
			if(cnt == 1)begin // X1
			    conv_temp[0] <= idata >> 4 ;  // *0.625
				if(i < 192)begin // padding case
					iaddr <= i % 64; 
				end else begin
					iaddr <= i % 64 + (i >> 6 << 6) - 128; // else
				end
			end else if(cnt == 2)begin // X2
				conv_temp[0] <= conv_temp[0] + (idata >> 3);  // *0.0125
				if((i & 13'b00111111) > 61)begin // i % 64 == 62 || i % 64 == 63
					if(i < 192)begin
						iaddr <= 63;
					end else begin
						iaddr <= (i >> 6 << 6) - 65; // -128 + 63
					end
				end else begin
					if(i < 192)begin
						iaddr <= (i % 64) + 2;
					end else begin
						iaddr <= (i >> 6 << 6) + (i % 64) - 126; // -128 + 2
					end
				end
			end else if(cnt == 3)begin // X3
				conv_temp[0] <= conv_temp[0] + (idata >> 4);  // *0.0625
				if(i % 64 == 0 || i % 64 == 1)begin
					iaddr <= (i >> 6) << 6; 
				end else begin
					iaddr <= i-2;
				end 
			end else if(cnt == 4)begin // X4
				conv_temp[0] <= conv_temp[0] + (idata >> 2);  // *0.25
				iaddr <= i; 
			end else if(cnt == 5)begin // X5
				conv_temp[1] <= idata;  // *1
				if(i % 64 == 62 || i % 64 == 63)begin
					iaddr <= (i >> 6 << 6) + 63;
				end else begin
					iaddr <= i + 2;
				end
			end else if(cnt == 6)begin // X6
				conv_temp[0] <= conv_temp[0] + (idata >> 2);  // *0.25 
				if(i % 64 == 0 || i % 64 == 1)begin
					if(i > 3904)begin
						iaddr <= 4032;
					end else begin
						iaddr <= (i >> 6 << 6) + 128;
					end
				end else begin
					if(i > 3969)begin
						iaddr <= 4032 + ((i-2) % 64);
					end else begin
						iaddr <= i + 126; 
					end
				end
			end else if(cnt == 7)begin // X7
				conv_temp[0] <= conv_temp[0] + (idata >> 4);  // *0.0625 
				if(i > 3967)begin
					iaddr <= 4032 + (i % 64);
				end else begin
					iaddr <= i + 128; 
				end
			end else if(cnt == 8)begin // X8
				conv_temp[0] <= conv_temp[0] + (idata >> 3);  // *0.0125
				if(i % 64 == 62 || i % 64 == 63)begin
					if(i > 3965)begin
						iaddr <= 4095;
					end else begin
						iaddr <= (i >> 6 << 6) + 191;
					end
				end else begin
					if(i > 3967)begin
						iaddr <= 4034 + (i % 64);
					end else begin
						iaddr <= 130 + i;
					end
				end
				i = i + 1;
			end else begin // RELU
				caddr_wr = i - 1;
				conv_temp[0] <= conv_temp[0] + (idata >> 4);  // *0.0625 				
				if((conv_temp[1] - conv_temp[0] + bias) & 13'b1000000000000)begin
					cdata_wr = 0;
				end else begin
					cdata_wr = conv_temp[1] - conv_temp[0] + bias; // - bias 0.75
				end
			end
			cnt = (cnt + 1)%10;			
		end
		LAYER_1:begin
			if(j == 0)begin
				cwr <= 1'b0; crd <= 1'b1; csel <= 1'b0; caddr_rd <= current + (address >> 5 << 7);  // read layer 0 data
				max_value <= 0;
			end else if(j == 1) begin
				caddr_rd <= current + 1 + (address >> 5 << 7); 
				max_value <= cmp ? cdata_rd : max_value;
			end else if(j == 2) begin
				caddr_rd <= current + 64 + (address >> 5 << 7); 
				max_value <= cmp ? cdata_rd : max_value;
			end else if(j == 3) begin
				caddr_rd <= current + 65 + (address >> 5 << 7); 
				max_value <= cmp ? cdata_rd : max_value;
			end else begin
				max_value = cmp ? cdata_rd : max_value;
				cwr <= 1'b1; crd <= 1'b0; csel <= 1'b1; caddr_wr <= address; 
				cdata_wr = (max_value[3:0] > 0)? max_value + 16 - max_value[3:0] : max_value; // Round up
				current = (current + 2)%64;
				address = address + 1;
			end 
			j <= (j + 1)%5;			
		end
		default:begin
			busy <= 1'b0;
		end
	endcase
	end
end
endmodule