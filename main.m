% This script will connect the picoscope, acquire a certain number of
% triggered acquisitions, then disconnect the picoscope.

clear all
close all
clc

%% Set path
restoredefaultpath
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\Functions\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\ps3000a\ 

% addpath C:\Users\HIFU\Documents\AcousticMeasurement\picoBase\
% addpath C:\Users\HIFU\Documents\AcousticMeasurement\picoBase\MATLAB\
% addpath C:\Users\HIFU\Documents\AcousticMeasurement\picoBase\MATLAB\Functions\
% addpath C:\Users\HIFU\Documents\AcousticMeasurement\picoBase\MATLAB\ps3000a\ 

%% Initialize picoscope

PicoStatus

[picoDevice, data] = picoConnect;
TRACENUM = 5;

deviceInfo = struct('methodinfo',[], 'structs',[], 'enuminfo',[], 'ThunkLibName',[]);
[deviceInfo.methodinfo, ...
    deviceInfo.structs, ...
    deviceInfo.enuminfo,...
    deviceInfo.ThunkLibName] = PS3000aMFile;

enuminfo = deviceInfo.enuminfo;

%% Acquire waveform
try
    waveform = triggeredAcq(TRACENUM, picoDevice, data, enuminfo);
catch
    stop_status = picoDisconnect(picoDevice);
    error('something went wrong bro.')
end
% disconnect(picoDevice);