# CNN-Convolution-Module

Brief Explanation

CNN convolution module is an implementation of CNN convolutional layer that can compute convolutions for variable filter sizes and stride values.
Module has clock, reset, data in/out, data valid/ready and command interfaces. Data is transferred through data in/out ports and module operation is controlled through command interface.
Module stores input data and filter coefficients in BRAMs and reads required data during the convolution operation. Input data and filter coefficients are represented as 32-bits signed fixed point number (signed fixed<32,24> format).
Convolution filter size and stride value can be set through data and command interfaces. 3x3, 4x4, 5x5, 6x6, 7x7 and 8x8 filter sizes and 0-7 stride values are supported. Input images having maximum size of 256x256 (65536 pixels) can be convolved with user defined filter size and stride value configuration.
CNN convolution module is composed of “layer_controller” top-level module and “convolution” sub-module.
