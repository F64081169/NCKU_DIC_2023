module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output reg [7:0] result; 

always @(*) begin
  case (select)
    1'b0: begin // find the maximum value
       if (number0 > number1 && number0 > number2 && number0 > number3)
            result <= number0;
       else if (number1 > number2 && number1 > number3) 
            result <= number1;
       else if (number2 > number3) 
             result <= number2;
       else 
            result <= number3;
     end
     1'b1: begin // find the minimum value
        if (number0 < number1 && number0 < number2 && number0 < number3)
            result <= number0;
        else if (number1 < number2 && number1 < number3)
            result <= number1;
        else if (number2 < number3)
            result <= number2;
        else
            result <= number3;
      end
  endcase
end

endmodule