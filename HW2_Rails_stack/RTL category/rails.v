module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output   reg    valid;
output   reg    result; 

reg [9:0]trains[9:0]; 
reg [3:0] numsOfTrain;
integer i;
integer cnt = 0; 
integer current;
integer top; 
reg flag;

always @(posedge clk or reset) begin
	if(reset)begin
		for(i = 0;i<10;i=i+1) trains[i] = 0;
		numsOfTrain = 0; cnt = 0; current = 0; valid = 0; top = 0; result = 0; flag = 0;
	end
	if(data>0) begin // start algorithm
		if(cnt == 0) begin 
			numsOfTrain = data;
			cnt = cnt + 1;
		end
		else begin
			if(cnt < numsOfTrain) begin // in input sequence
				if(data < (current + 1)) begin
					if(data == trains[top-1])begin 
						trains[top -1] <= 0; 
						top = top - 1; 
					end
					else begin
						flag = 1;
					end
				end
				else begin
					for(i=current+1;i<data;i=i+1) begin 
						trains[top] <= i;
						top = top + 1;	
					end
					current = data; 
				end
				cnt = cnt + 1;
			end
			else begin
				valid = 1;
				if(flag==1) result = 0;
				else result = 1;
			end
		end 
	end
	else begin
		for(i = 0;i<10;i=i+1) trains[i] = 0;
		numsOfTrain = 0; cnt = 0; current = 0; valid = 0; top = 0; result = 0; flag = 0;
	end
end
endmodule
