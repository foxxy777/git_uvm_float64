`include "uvm_macros.svh"
`include "float64_add_main.v"

import uvm_pkg::*;

class transaction_item extends uvm_sequence_item;
  rand bit [63:0]  	a;
  rand bit [63:0] 	b;
  bit [63:0] 		return_value;
  bit [63:0]		correct_value;

  `uvm_object_utils_begin(transaction_item)
  	`uvm_field_int (a, UVM_DEFAULT)
  	`uvm_field_int (b, UVM_DEFAULT)
  	`uvm_field_int (return_value, UVM_DEFAULT)
  	`uvm_field_int (correct_value, UVM_DEFAULT)
  `uvm_object_utils_end
  
  function new(string name = "transaction_item");
    super.new(name);
  endfunction
endclass


class gen_item_seq extends uvm_sequence;
  `uvm_object_utils(gen_item_seq)
  function new(string name="gen_item_seq");
    super.new(name);
  endfunction
  
  rand int num; 	
  
  constraint c1 { num == 46; }

  parameter NUMBER = 46;

  reg [63:0] a_input[0:NUMBER-1];
reg [63:0] b_input[0:NUMBER-1];
reg [63:0] z_output[0:NUMBER-1];

  virtual task pre_body();
begin
	$readmemh("a_input.txt",a_input);
	$readmemh("b_input.txt",b_input);
	$readmemh("z_output.txt",z_output);
end
  endtask

  virtual task body();
    for (int i = 0; i < num; i ++) begin
    	transaction_item m_item = transaction_item::type_id::create("m_item");
    	start_item(m_item);
    	//m_item.randomize();
   m_item.a = a_input[i];
   m_item.b = b_input[i];
   m_item.correct_value = z_output[i];

    	`uvm_info("SEQ", $sformatf("Generate new item: {implement m_item.print() in generator} "), UVM_LOW)
    	m_item.print();
      	finish_item(m_item);
    end
    `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
  endtask
endclass

class driver extends uvm_driver #(transaction_item);              
  `uvm_component_utils(driver)
  function new(string name = "driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  //ע��interface
  virtual DUT_if vif;
  uvm_event ev;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual DUT_if)::get(this, "", "DUT_vif", vif))
      `uvm_fatal("DRV", "Could not get vif")
    ev = uvm_event_pool::get_global("ev_ab");
    //ev.reset;//�ᱨ��������û�е�һ��trigger��û�����������event
  endfunction

  
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin
      transaction_item m_item;
      `uvm_info("DRV", $sformatf("{run_phase} Wait for item from sequencer"), UVM_LOW)
      //if(ev.is_off)//����������ev��ǰ��������������Ĳ���������ѭ��
      begin
	      //fork//�Ľ��̿�����drive_item����ģ���Ҫ��get_next_item����ϵͳĬ�Ϻ�����˳��
      seq_item_port.get_next_item(m_item);
      drive_item(m_item);//30����һ�� 1030���ڶ���
      //ev = uvm_event_pool::get_global("ev_ab");//����build_phase��һ��
      `uvm_info("DRV", $sformatf("{run_phase} trigger event"), UVM_LOW)
      //ev.trigger();//��һ����1050�Ŵ��� �ڶ��ο�ʼ�����Ǽ�ʱ��2030���̴���
      //join
      seq_item_port.item_done();
      end
    end
  endtask

  
  virtual task drive_item(transaction_item m_item);
    vif.a 	<= m_item.a;
    vif.b 	<= m_item.b;
    vif.correct_value 	<= m_item.correct_value;
          `uvm_info(get_type_name(), $sformatf("{drive_item} a=0x%0h b=0x%0h correct_value=0x%0h", m_item.a, m_item.b, m_item.correct_value), UVM_LOW)
    #1000;
    ev.trigger();
    #100;//��һ��trigger event��ʱ��������ʱһ�����ڣ�����Ҫ��drive����������ʱҲ���ϣ���Ȼ����ֵ�һ�����������ԭ���ǵ�һ������event trigger�ȵڶ�������д������һ�����ڣ�����30ns���ĵ�һ��return_value���ڶ����correct_value���бȽ���
  endtask
endclass

class monitor extends uvm_monitor;//monitor����agent(a0)������������Ȩ����ȡvif��
  `uvm_component_utils(monitor)
  function new(string name="monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  uvm_analysis_port  #(transaction_item) mon_analysis_port;
  virtual DUT_if vif;
  uvm_event ev;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual DUT_if)::get(this, "", "DUT_vif", vif))
      `uvm_fatal("MON", "Could not get vif")
    mon_analysis_port = new ("mon_analysis_port", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
      ev = uvm_event_pool::get_global("ev_ab");
      `uvm_info(get_type_name(),$sformatf("{run_phase} waiting for event triggered for first time"),UVM_LOW)//get_type_name get�ľ���new�����string name = monitor
      ev.wait_trigger;
      sample_port("Thread0");
  endtask
  
  virtual task sample_port(string tag="");
    forever begin
      @(posedge vif.clk);
      if (ev.is_on) begin
        transaction_item item = new;
       `uvm_info("MON",$sformatf("{sample port} time = %0t event triggerd",$time),UVM_LOW)	
        item.a = vif.a;
        item.b = vif.b;
        item.return_value = vif.return_value;
        item.correct_value = vif.correct_value;
        @(posedge vif.clk);
        mon_analysis_port.write(item);
       
       `uvm_info("MON",$sformatf("{sample port} time = %0t print item sampled by Monitor",$time),UVM_LOW)	

        item.print(); 
       `uvm_info("MON",$sformatf("{sample port} time = %0t event reset",$time),UVM_LOW)	
	ev.reset;
	
end	
      end
  endtask
endclass

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  function new(string name="scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  uvm_analysis_imp #(transaction_item, scoreboard) m_analysis_imp;
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_analysis_imp = new("m_analysis_imp", this);
  endfunction
  
  virtual function write(transaction_item item);      
     begin
	     if(item.return_value == item.correct_value)
	     begin
		     $display("---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
          `uvm_info("SCBD", $sformatf("PASS! a=0x%0h b=0x%0h return_value=0x%0h correct_value=0x%0h ", item.a, item.b, item.return_value,item.correct_value), UVM_LOW)
		     $display("---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
	     end
  else
  begin
		     $display("---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
          `uvm_info("SCBD", $sformatf("FAIL! a=0x%0h b=0x%0h return_value=0x%0h correct_value=0x%0h ", item.a, item.b, item.return_value,item.correct_value), UVM_LOW)
		     $display("---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
	     end
      end
  endfunction
endclass
      
class agent extends uvm_agent;
  `uvm_component_utils(agent)
  function new(string name="agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  driver 		d0; 		
  monitor 		m0; 		
  uvm_sequencer #(transaction_item)	s0; 	

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s0 = uvm_sequencer#(transaction_item)::type_id::create("s0", this);
    d0 = driver::type_id::create("d0", this);
    m0 = monitor::type_id::create("m0", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d0.seq_item_port.connect(s0.seq_item_export);
  endfunction

endclass

class env extends uvm_env;//envû��ֱ���õ�vif�����ԾͲ���config_db::get
  `uvm_component_utils(env)
  function new(string name="env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  agent 		a0; 		
  scoreboard	sb0; 	
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a0 = agent::type_id::create("a0", this);
    sb0 = scoreboard::type_id::create("sb0", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a0.m0.mon_analysis_port.connect(sb0.m_analysis_imp);
  endfunction
endclass


class test extends uvm_test;
  `uvm_component_utils(test)
  function new(string name = "test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  env e0;
  virtual DUT_if vif;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e0 = env::type_id::create("e0", this);
    if (!uvm_config_db#(virtual DUT_if)::get(this, "", "DUT_vif", vif))
      `uvm_fatal("TEST", "Did not get vif")
      
      uvm_config_db#(virtual DUT_if)::set(this, "e0.a0.*", "DUT_vif", vif);//
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    gen_item_seq seq = gen_item_seq::type_id::create("seq");
    phase.raise_objection(this);//?
    $display("apply_reset");
    apply_reset();
    
    seq.randomize();//ֻrandomize�Լ��е�ѭ������num��Ȼ��ִ��body()����ִ��num�ε�seq_item������
    seq.start(e0.a0.s0);
    phase.drop_objection(this);
  endtask
  
task reset_dut;
  endtask

  virtual task apply_reset();
  	vif.start <= 0;
	vif.rstN <= 1;
	#10;
	vif.rstN <= 0;
	#10;
	vif.rstN <= 1;
	vif.start <= 1;
	vif.a = 64'h7FF8000000000000;
	vif.b = 64'h3FF0000000000000;
	#10;
    //repeat(5) @ (posedge vif.clk);
  endtask
endclass

interface DUT_if (input bit clk);
  logic 		rstN;
  logic 		start;
  logic 		fin;
  logic [63:0] 	a;
  logic [63:0]	b;
  logic [63:0] 	return_value;
  logic [63:0] 	correct_value;

endinterface

module tb;
  reg clk;
  
  always #10 clk =~ clk;
  DUT_if 	_if (clk);

float64_add_DUT_RTL float64_add_DUT_RTL_1(
	.clk(clk),
	.rstN(_if.rstN),
	.start(_if.start),
	.fin(_if.fin),
	.a(_if.a),
	.b(_if.b),
	.return_value(_if.return_value));

  test t0;
  
  initial begin
    clk <= 0;
    uvm_config_db#(virtual DUT_if)::set(null, "uvm_test_top", "DUT_vif", _if);//ע��interface
    run_test("test");
  end
  
  initial begin
    $dumpfile ("dump.vcd");
    $dumpvars;
  end
endmodule
