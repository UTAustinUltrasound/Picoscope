function [picoDevice, data] = picoConnect
%% Declare variables

data.TRUE = 1;
data.FALSE = 0;

data.BUFFER_SIZE = 1024*16; % Maximum Buffer size for 3406B is 16384 (1024*16)
data.timebase = 3;  % Highest sampling rate for 3406B is with a time base of 3
                    % sampling rate is (timebase-2)/125E6; time base of 3 
                    % corresponds to a sampling interval of 8 ns
data.oversample = 1;

data.scaleVoltages = data.TRUE;
data.inputRangesmV = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];

%% Device Connection

% Create device
picoDevice = icdevice('C:\Users\HIFU\Documents\AcousticMeasurement\picobase\MATLAB\ps3000a\PS3000a_IC_drv.mdd', ''); % Specify serial number as 2nd argument if required.

% Connect device
connect(picoDevice);

end