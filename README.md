# CNN Convolution Module
## Brief Explanation
CNN convolution module is an implementation of CNN convolutional layer that can compute convolutions for variable filter sizes and stride values. 

Module has clock, reset, data in/out,  data valid/ready and command interfaces. Data is transferred through data in/out ports and module operation is controlled through command interface. 

Module stores input data and filter coefficients in BRAMs and reads required data during the convolution operation. Input data and filter coefficients are represented as 32-bits signed fixed point number (signed fixed<32,24> format).

Convolution filter size and stride value can be set through data and command interfaces. 3x3, 4x4, 5x5, 6x6, 7x7 and 8x8 filter sizes and 0-7 stride values are supported. Input images having maximum size of 256x256 (65536 pixels) can be convolved with user defined filter size and stride value configuration. 

CNN convolution module is composed of “layer_controller”  top-level module and “convolution” sub-module. 

## Layer Controller Module
Layer controller module stores input data and filter coefficients in BRAMs, controls convolution module, reads convolution results from BRAM and sends results to output data port. 

This module processes “store input data”, “store filter data” and “start convolution” commands. Input data is stored in 4 true dual port BRAMs sequentially when “store input data” command is received. Filter coefficients are stored in a true dual port BRAM when “store filter data” command is received. Convolution module is triggered by the “start convolution” command. 

After convolution module completes its operation,  layer controller module starts reading result data from BRAM and asserts data ready signal to indicate that results can be read from the output port.

## Convolution Module
Convolution module controls the movement of convolution filter over input matrix/input image and computes data multiplication-accumulation.
 
Module calculates BRAM addresses of required input data and filter coefficients for each filter position and reads data values from BRAMs. If there is no memory collision, 8 input data - filter coefficient pairs can be read, multiplied and accumulated concurrently at every clock cycle. If there is memory collision, module buffers all relevant data and waits for memory access controller to complete its operation. 

At the end of the convolution operation, results are stored in the BRAM and operation complete indicator is sent to the layer controller module. 

## BRAM Interfaces
Input data is stored in 4 true dual port BRAMs each having 16384 address space size. “Data BRAM1”, “Data BRAM2”, “Data BRAM3” and “Data BRAM4” stores input data pairs sequentially. As an example,  element of the input matrix at row-0 and column-0 is stored in  BRAM1 address 0,   element at  row-0 and column-1 is stored in  BRAM1 address 1,  element at  row-0 and column-2 is stored in  BRAM2 address 0,  element at  row-0 and column-3 is stored in  BRAM2 address 1,  element at  row-0 and column-4 is stored in  BRAM3 address 0,  element at  row-0 and column-5 is stored in  BRAM3 address 1,  element at  row-0 and column-6 is stored in  BRAM4 address 0,  element at  row-0 and column-7 is stored in  BRAM4 address 1,  element at  row-0 and column-8 is stored in  BRAM1 address 2,  element at  row-0 and column-9 is stored in  BRAM1 address 3, ...

Layer controller module has write access and convolution module has read access to input data BRAMs.

Filter coefficient data is stored in 1 true dual port BRAM (Filter BRAM) having 64 address space size. Layer controller module has write access and convolution module has read access to this BRAM. 

Result data is stored in simple port BRAM (Result BRAM) having 65536 address space size. Layer controller module has read access and convolution module has write access to this BRAM.
