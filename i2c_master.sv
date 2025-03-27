`timescale 1ns / 1ps

module i2c_master(
  input clk,rst,newd,op,
  input [6:0] addr,
  input [7:0] din,
  inout sda,
  output scl,
  output [7:0] dout,
  output reg busy,ack_err,done
);
  reg scl_t=0;
  reg sda_t=0;
  
  parameter sys_freq=40000000;
  parameter i2c_freq=100000;
  
  parameter clk_count4=(sys_freq/i2c_freq);
  parameter clk_count1=clk_count4/4;
  
  integer count1=0;
  reg i2c_clk=0;
  
  reg [1:0] pulse = 0;
  always@(posedge clk)
  begin
    if(rst)
      begin
        pulse<=0;
        count1<=0;        
      end
    else if(busy==1'b0)
      begin
        pulse<=0;
        count1<=0;
      end
    else if(count1==clk_count1-1)
      begin
        pulse <=1;
        count1<=count1+1;
      end
    else if(count1==clk_count1*2-1)
      begin
        pulse<=2;
        count1<=count1+1;
      end
    else if(count1==clk_count1*3-1)
      begin
        pulse<=3;
        count1<=count1+1;
      end
    else if(count1==clk_count1*4-1)
      begin
        pulse<=0;
        count1<=0;
      end
    else begin
      count1<=count1+1;
    end
  end
  
  reg[3:0] bitcount=0;
  reg[7:0] data_addr=0, data_tx=0;
  reg r_ack=0;
  reg [7:0] rx_data=0;
  reg sda_en=0;
  
  typedef enum logic[3:0] {idle=0, start=1, write_addr=2, ack_1=3,
    write_data=4, read_data=5, stop=6, ack_2=7, master_ack=8} state_type;
  state_type state=idle;
  
  always@(posedge clk)
    begin
      if(rst)
        begin
       	  bitcount<=0;
          data_addr<=0;
          data_tx<=0;
          scl_t<=1;
       	  sda_t<=1;
          state<=idle;
          busy<=1'b0;
          ack_err<=1'b0;
          done<=1'b0;
        end
      else begin
        case(state)
          idle: begin
            done<=1'b0;
            if(newd==1'b1)
              begin
                data_addr<={addr,op};
                data_tx<=din;
                busy<=1'b1;
                state<=start;
                ack_err<=1'b0;
              end
            else begin
              data_addr<=0;
              data_tx<=0;
              busy<=1'b0;
              state<=idle;
              ack_err<=1'b0;
            end
          end
        start: begin
          sda_en<=1'b1;
          case(pulse)
            0: begin scl_t<=1'b1; sda_t<=1'b1; end
            1: begin scl_t<=1'b1; sda_t<=1'b1; end
            2: begin scl_t<=1'b1; sda_t<=1'b0; end
            3: begin scl_t<=1'b1; sda_t<=1'b0; end
          endcase
          
          if(count1==clk_count1*4 - 1)
            begin
              state<=write_addr;
              scl_t<=1'b0;
            end
          else state<=start;
            end
          
          write_addr: begin
            sda_en=1'b1;
            if(bitcount<=7)
              begin
                case(pulse)
                  0: begin scl_t<=1'b0; sda_t<=1'b0; end
                  1: begin scl_t<=1'b0; sda_t<= data_addr[7-bitcount]; end
                  2: begin scl_t<=1'b1; end
                  3: begin scl_t<=1'b1; end
                endcase
                if(count1==clk_count1*4 - 1)
                  begin
                    state<=write_addr;
                    scl_t<=1'b0;
                    bitcount<=bitcount+1;
                  end
                else begin
                state<=write_addr;
                end
              end
            else begin
              state<=ack_1;
              bitcount<=0;
              sda_en<=1'b0;
            end
          end
          
          ack_1:
            begin
              sda_en<=1'b0;
              case(pulse)
                0: begin scl_t<=1'b0; sda_t<=1'b0; end
                1: begin scl_t<=1'b0; sda_t<=1'b0; end
                2: begin scl_t<=1'b1; sda_t<=1'b0; r_ack<= sda; end
                3: begin scl_t<=1'b1; end
              endcase
              
              if(count1==clk_count1*4 - 1) begin
                if(r_ack==1'b0 && data_addr[0]==1'b0) begin
                  state<=write_data;
                  sda_t<=1'b0;
                  sda_en<=1'b1;
                  bitcount<=0;
                end
                else if(r_ack==1'b0 && data_addr[0]==1'b1) begin
                  state<=read_data;
                  sda_t<=1'b1;
                  sda_en<=1'b0;
                  bitcount<=0;
                end
                else begin
                  state<=stop;
                  sda_en<=1'b1;
                  ack_err<=1'b1;
                end
              end
              else begin state<=ack_1; end
            end
          
          write_data: begin
            if(bitcount<=7) begin
              case(pulse)
                0: begin scl_t<=1'b0; end
                1: begin scl_t<=1'b0; sda_en<=1'b1; sda_t<=data_tx[7-bitcount]; end
                2: begin scl_t<=1'b1; end
                3: begin scl_t<=1'b1; end
              endcase
              if(count1==clk_count1*4-1) begin
                state<=write_data;
                scl_t<=1'b0;
                bitcount<=bitcount+1;
              end
              else begin
                state<=write_data;
              end
            end
            else begin
              state<=ack_2;
              bitcount<=0;
              sda_en<=1'b0;
            end
          end
          
          read_data: begin
            sda_en<=1'b0;
            if(bitcount<=7) begin
              case(pulse)
                0: begin scl_t<=1'b0; sda_t<=1'b0; end
                1: begin scl_t<=1'b0; sda_t<=1'b0; end
                2: begin scl_t<=1'b1; rx_data[7:0]<= (count1==200)?{rx_data[6:0],sda}: rx_data; end
                3: begin scl_t<=1'b1; end
              endcase
              if(count1==clk_count1*4-1) begin
                state<=read_data;
                scl_t<=1'b0;
                bitcount<=bitcount+1;
              end
              else begin
                state<=read_data;
              end
            end
            else begin
              state<=master_ack;
              bitcount<=0;
              sda_en<=1'b1;
            end
          end
          master_ack: begin
            sda_en<=1'b1;
            case(pulse)
              0: begin scl_t<=1'b0; sda_t<=1'b1; end
              1: begin scl_t<=1'b0; sda_t<=1'b1; end
              2: begin scl_t<=1'b1; sda_t<=1'b1; end 
              3: begin scl_t<=1'b1; sda_t<=1'b1; end
            endcase
            
            if(count1==clk_count1*4 - 1)
              begin
                sda_t<=1'b0;
                state<=stop;
                sda_en<=1'b1;
              end
            else begin state<= master_ack; end
           end
          
          ack_2: begin
            sda_en<=1'b0;
            case(pulse)
              0: begin scl_t<=1'b0; sda_t<=1'b0; end
              1: begin scl_t<=1'b0; sda_t<=1'b0; end
              2: begin scl_t<=1'b1; sda_t<=1'b0; r_ack<=sda; end
              3: begin scl_t<=1'b1;  end
            endcase
          
            if(count1==clk_count1*4-1)
                begin
                  sda_t<=1'b0;
                  sda_en<=1'b1;
                  if(r_ack==1'b0) begin
                    state<=stop;
                    ack_err<=1'b0;
                  end
                  else begin
                    state<=stop;
                    ack_err<=1'b1;
                  end
                end
              else begin
                state<=ack_2;
              end
          end
          stop: begin
            sda_en<=1'b1;
            case(pulse)
              0: begin scl_t<=1'b1; sda_t<=1'b0; end
              1: begin scl_t<=1'b1; sda_t<=1'b0; end
              2: begin scl_t<=1'b1; sda_t<=1'b1; end
              3: begin scl_t<=1'b1; sda_t<=1'b1; end
            endcase
            
            if(count1==clk_count1*4-1)
              begin
              state<= idle;
                scl_t<=1'b0;
                busy<=1'b0;
                sda_en<=1'b1;
                done<=1'b1;
              end
            else begin state<=stop; end
          end
          default : state<=idle;
        endcase
      end
    end
    
  assign sda=(sda_en==1)?(sda_t==0)?1'b0:1'b1:1'bz;
  assign scl=scl_t;
  assign dout=rx_data;
endmodule