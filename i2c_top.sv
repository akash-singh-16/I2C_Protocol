`timescale 1ns / 1ps

`include "i2c_master.sv"
`include "i2c_slave.sv"
`include "i2c_if.sv"
module i2c_top(
  input clk,rst,newd,op,
  input[6:0] addr, 
  input[7:0] din,
  output[7:0] dout,
  output busy,ack_err,
  output reg done
  );
  wire sda,scl;
  wire ack_errm,ack_errs;
  
  i2c_master master(clk,rst,newd,op,addr,din,sda,scl,dout,busy,ack_errm,done);
  i2c_slave slave(scl,clk,rst,sda,ack_errs,);
  
  assign ack_err= ack_errs|ack_errm;
endmodule 

