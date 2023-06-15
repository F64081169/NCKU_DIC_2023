`include "MMS_4num.v"
module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
input  [7:0] number4;
input  [7:0] number5;
input  [7:0] number6;
input  [7:0] number7;
output reg[7:0] result; 
wire [7:0] result1;
wire [7:0] result2;


MMS_4num MMS_4num1(.result(result1), .select(select), .number0(number0), .number1(number1), .number2(number2), .number3(number3));
MMS_4num MMS_4num2(.result(result2), .select(select), .number0(number4), .number1(number5), .number2(number6), .number3(number7));

always @(*) begin
     case(select)
	1'b0:begin  // find the maximum value
	        if(result1<result2)
		result<=result2;
		else 
		result<=result1;
	end
	1'b1:begin  // find the minimum value
 		if(result1<result2)
		result<=result1;
		else 
		result<=result2;
	end
     endcase
end

endmodule

