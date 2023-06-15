module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;

// state design
reg [1:0] state, next_state;
parameter READY = 0,NUMBER = 1,EQUAL_POP = 2,RESULT = 3;

// stack design
reg [6:0] stack[0:7];
reg [6:0] opstack[0:7];
reg [7:0] top_stack;
reg [7:0] top_opstack;
reg [7:0] ptr, op_ptr;

reg [3:0] i;

reg mul_flag, mul_flag2, para_flag, paraCnt;

always@(*)begin
	case(state)
		READY:begin
            if(ready)begin
                next_state <= NUMBER;
            end else begin
                next_state <= READY;
            end
        end
        NUMBER:begin
            if(ascii_in == 61)begin // ascii_in == '='
                next_state <= EQUAL_POP;
            end else begin
                next_state <= NUMBER;
            end
        end
        EQUAL_POP:begin
            if(op_ptr==top_opstack)begin
               next_state <= RESULT;
            end else begin
                next_state <= EQUAL_POP;
            end
        end
        RESULT:begin
            next_state <= READY;
        end
        default:begin
        end
	endcase
end

// output logic
always@(posedge clk or posedge rst)begin
	if(rst)begin
        state <= READY; valid <= 0; top_opstack <= 0; top_stack <= 0; ptr <= 0; ptr <= 0; op_ptr <= 0; mul_flag <= 0;
        para_flag <= 0; mul_flag2 <= 0; paraCnt <= 0;
	end else begin
        state <= next_state;
		case(state) 
            READY:begin // 0
                valid <= 0; top_opstack <= 0; top_stack <= 0; ptr <= 0; ptr <= 0; op_ptr <= 0; mul_flag <= 0;
                para_flag <= 0; mul_flag2 <= 0; paraCnt <= 0;
                for (i = 4'd0;i<4'd8 ;i=i+4'd1) begin 
                    stack[i] <= 7'd0;
                    opstack[i] <= 7'd0;
                end
                if(ready)begin
                    if(ascii_in == 40) begin //  ascii_in == '('
                        para_flag <= 1;
                    end else if(ascii_in > 47 && ascii_in <58)begin
                        stack[0] <= ascii_in - 48;
                        top_stack <= 1;
                    end else begin
                        stack[0] <= ascii_in - 87;
                        top_stack <= 1;
                    end
                end else begin
                end
            end
            NUMBER:begin // 1
                if(mul_flag == 1 && top_stack>0)begin // mul_flag == 1
                    if(ascii_in == 40)begin //  ascii_in == '('
                        para_flag = 1;
                        mul_flag2 = 1;
                    end else if(ascii_in == 41)begin //  ascii_in == ')'
                        if(mul_flag2 == 1)begin
                            stack[top_stack-2] <= stack[top_stack-2] * stack[top_stack-1];
                            mul_flag2 <= 0;
                            top_stack <= top_stack - 1;
                        end else begin
                        end
                        para_flag <= 0;
                        paraCnt <= 0;
                    end else if(ascii_in > 47 && ascii_in <58)begin
                        stack[top_stack-1] <= stack[top_stack-1] * (ascii_in - 48);
                    end else if(ascii_in > 96 && ascii_in <103)begin
                        stack[top_stack-1] <= stack[top_stack-1] * (ascii_in - 87);
                    end else begin
                    end
                    mul_flag <= 0;
                end else begin
                    if(ascii_in == 40)begin //  ascii_in == '('
                        para_flag = 1;
                    end else if(ascii_in == 41)begin //  ascii_in == ')'
                        if(mul_flag2 == 1)begin
                            stack[top_stack-2] <= stack[top_stack-2] * stack[top_stack-1];
                            mul_flag2 <= 0;
                            top_stack <= top_stack - 1;
                        end else begin
                        end
                        para_flag <= 0;
                        paraCnt <= 0;
                    end else if(ascii_in == 42)begin  //  ascii_in == '*'
                        if((opstack[top_opstack-1] == 43 || opstack[top_opstack-1] == 45) && top_opstack>0) begin     
                                mul_flag <= 1;
                        end else begin
                            opstack[top_opstack] = 42;
                            top_opstack = top_opstack + 1;
                        end
                    end else if(ascii_in == 43)begin // '+'
                        opstack[top_opstack] <= ascii_in;
                        top_opstack <= top_opstack + 1;
                    end else if(ascii_in == 45) begin // '-'
                        opstack[top_opstack] <= ascii_in;
                        top_opstack <= top_opstack + 1;
                    end else if(ascii_in > 47 && ascii_in < 58)begin
                        if(para_flag)begin
                           if(paraCnt==0)begin
                                stack[top_stack] = ascii_in-48;
                                top_stack = top_stack + 1;
                                paraCnt = 1;
                            end else begin
                                if(opstack[top_opstack-1]==43)begin
                                    stack[top_stack-1] = stack[top_stack-1] + (ascii_in-48);
                                end else if(opstack[top_opstack-1]==45) begin
                                    stack[top_stack-1] = stack[top_stack-1] - (ascii_in-48);
                                end else begin
                                    stack[top_stack-1] = stack[top_stack-1] * (ascii_in-48);
                                end
                                    opstack[top_opstack-1] = 0;
                                    top_opstack = top_opstack - 1;
                            end
                        end else begin
                            stack[top_stack] <= (ascii_in-48);
                            top_stack <= top_stack + 1;
                        end
                    end else if(ascii_in > 96 && ascii_in < 103)begin
                        if(para_flag)begin
                            if(paraCnt==0)begin
                                stack[top_stack] = ascii_in-87;
                                top_stack = top_stack + 1;
                                paraCnt = 1;
                            end else begin
                                if(opstack[top_opstack-1]==43)begin
                                    stack[top_stack-1] = stack[top_stack-1] + (ascii_in-87);
                                end else if(opstack[top_opstack-1]==45) begin
                                    stack[top_stack-1] = stack[top_stack-1] - (ascii_in-87);
                                end else begin
                                    stack[top_stack-1] = stack[top_stack-1] * (ascii_in-87);
                                end
                                    opstack[top_opstack-1] = 0;
                                    top_opstack = top_opstack - 1;
                            end
                        end else begin
                            stack[top_stack] <= (ascii_in-87);
                            top_stack <= top_stack + 1;
                        end
                    end else begin
                    end
                end
            end      
            EQUAL_POP:begin // 2
                if(top_stack > 1)begin
                    case(opstack[op_ptr])
                    43:begin // ascii_in == '+'
                        stack[ptr+1] <=  stack[ptr] + stack[ptr+1];
                    end
                    45:begin // ascii_in == '-'
                        stack[ptr+1] <=  stack[ptr] -  stack[ptr+1];
                    end
                    42:begin // ascii_in == '*'
                        stack[ptr+1] <=  stack[ptr] *  stack[ptr+1];
                    end 
                    default:begin
                    end
                endcase
                    ptr <= ptr + 1;
                    op_ptr <= op_ptr + 1;
                end else begin
                end                                       
            end
            RESULT:begin // 3
                valid <= 1;
                result <= stack[top_stack-1];
            end
            default:begin
            end
		endcase
	end 
end
endmodule 