`timescale 1ns / 1ps

class transaction;
  bit newd;
  rand bit op;
  rand bit[7:0] din;
  rand bit [6:0] addr;
  bit [7:0] dout;
  bit done;
  bit busy;
  bit ack_err;
  
  constraint add_c {addr>1; addr<5;din>1; din<10;}
  
  constraint rd_wr_c {
    op dist{1 :/ 50, 0:/50};
  }
  
endclass

class generator;
  transaction tr;
  mailbox #(transaction) mbxgd;
  event done;
  event drvnext;
  event sconext;
  
  int count=0;
  
  function new(mailbox #(transaction) mbxgd);
    this.mbxgd=mbxgd;
    tr=new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error("[GEN] : Randomization Failed");
      mbxgd.put(tr);
      $display("[GEN] : op = %0d, Address = %0d, din = %0d",tr.op,tr.addr,tr.din);
      @(drvnext);
      @(sconext);
    end
    ->done;
  endtask
endclass

class driver;
  virtual i2c_if vif;
  transaction tr;
  event drvnext;
  mailbox #(transaction) mbxgd;
  
  function new(mailbox #(transaction) mbxgd);
    this.mbxgd=mbxgd;   
  endfunction
 
  task reset();
    vif.rst<=1'b1;
    vif.newd<=1'b0;
    vif.op<=1'b0;
    vif.din<=0;
    vif.addr<=0;
    repeat(10) @(posedge vif.clk);
    vif.rst<=1'b0;
    $display("[DRV] : Reset Done");
    $display("-------------------------");
  endtask
  
  task write();
    vif.rst<=1'b0;
    vif.newd<=1'b1;
    vif.op<=1'b0;
    vif.din<=tr.din;
    vif.addr<=tr.addr;
    repeat(5) @(posedge vif.clk);
    vif.newd<=1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP: Write, Address = %0d, Din = ",tr.addr,tr.din);
    vif.newd<=1'b0;
  endtask
  
  task read();
    vif.rst<=1'b0;
    vif.newd<=1'b1;
    vif.op<=1'b1;
    vif.din<=0;
    vif.addr<=tr.addr;
    repeat(5) @(posedge vif.clk);
	vif.newd<=1'b0;
    @(posedge vif.done)
    $display("[DRV] : OP = Read, Address = %0d, Dout = %0d",tr.addr,vif.dout);
  endtask
  
  task run();
    tr=new();
    forever begin
      mbxgd.get(tr);
      
      if(tr.op==1'b0) write();
      else read();
      
      ->drvnext;
    end
  endtask
endclass
   
class monitor;
  virtual i2c_if vif;
  transaction tr;
  mailbox #(transaction) mbxms;
  
  function new(mailbox #(transaction) mbxms);
    this.mbxms=mbxms;
  endfunction
  
  task run();
    tr=new();
    
    forever begin
      @(posedge vif.done);
      tr.din=vif.din;
      tr.addr=vif.addr;
      tr.op=vif.op;
      tr.dout=vif.dout;
      repeat(5) @(posedge vif.clk);
      mbxms.put(tr);
      $display("[MON] : OP = %0d, Address = %0d, Din = %0d, Dout = %0d",tr.op,tr.addr, tr.din, tr.dout);
    end
  endtask
endclass

class scoreboard;
  transaction tr;
  mailbox #(transaction) mbxms;
  event sconext;
  
  bit[7:0] temp;
  bit[7:0] mem[128] = '{default:0};
  
  function new(mailbox #(transaction) mbxms);
  this.mbxms=mbxms;
    
    for(int i = 0; i<128; i++)
      begin
        mem[i]=i;
      end
  endfunction
  
  task run();
    forever begin
      mbxms.get(tr);
      temp=mem[tr.addr];
      
      if(!tr.op)
        begin
          mem[tr.addr] = tr.din;
          $display("[SCO] : Data Stored -> Address = %0d Data = %0d",tr.addr,tr.din);
          $display("------------------------------------");
        end
      else begin
        if(tr.dout==temp)
          $display("[SCO] : Data Read -> Data Matched, Expected = %0d, Recieved = %0d", temp, tr.dout);
        else $display("[SCO] : Data Read -> Data Mismatched, Expected = %0d Recieved = %0d",temp,tr.dout);
        
        $display("----------------------------------------");
      end
      ->sconext;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  
  mailbox #(transaction) mbxgd,mbxms;
  
  virtual i2c_if vif;
  
  function new(virtual i2c_if vif);
    mbxgd=new();
    mbxms=new();
    gen=new(mbxgd);
    drv=new(mbxgd);
    mon=new(mbxms);
    sco=new(mbxms);
    
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    
    gen.drvnext=nextgd;
    drv.drvnext=nextgd;
    
    gen.sconext=nextgs;
    sco.sconext=nextgs;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
  fork
    gen.run();
    drv.run();
    mon.run();
    sco.run();
  join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  i2c_if vif();
  environment env;
  
  i2c_top dut(vif.clk,vif.rst,vif.newd,vif.op,vif.addr,vif.din,vif.dout,vif.busy,vif.ack_err, vif.done);
  
  initial begin
    vif.clk<=0;
  end
  always #5 vif.clk<=~vif.clk;
  
  initial begin
    env=new(vif);
	env.gen.count=10;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  
endmodule  
