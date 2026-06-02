// Hierarchy Level: 1
// FIR Rate Converter

module dsphdl_FIRRateConverter
          (clk,
           reset,
           enb,
           dataIn,
           validIn,
           dataOut,
           validOut);


  input   clk;
  input   reset;
  input   enb;
  input   signed [15:0] dataIn;  // sfix16_En15
  input   validIn;
  output  signed [15:0] dataOut;  // sfix16_En15
  output  validOut;


  wire controllerPhaseOut;  // ufix1
  wire controllerValidOut;
  wire countReached;
  wire filterValidOut;


  FIR_Rate_Converter_Controller u_controllerInst (.clk(clk),
                                                  .reset(reset),
                                                  .enb(enb),
                                                  .dataValid(validIn),
                                                  .phase(controllerPhaseOut),  // ufix1
                                                  .phaseValid(controllerValidOut),
                                                  .ready(countReached)
                                                  );

  FIR_Rate_Conversion_Filter u_filterInst (.clk(clk),
                                           .reset(reset),
                                           .enb(enb),
                                           .data(dataIn),  // sfix16_En15
                                           .dataValid(validIn),
                                           .phase(controllerPhaseOut),  // ufix1
                                           .phaseValid(controllerValidOut),
                                           .dataOut(dataOut),  // sfix16_En15
                                           .validOut(filterValidOut)
                                           );

  assign validOut = filterValidOut;

endmodule  
