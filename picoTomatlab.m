% Following function opens connects the picoscope to matlab, acquries and
% captures data and then saves the data for each trace in a matrix that has
% dimensions SAMPLE SIZE X TRACENUM; 

% Upated: 10/03/14

function dataCap = picoTomatlab(TRACENUM)
% Edit as required-- sets path to drivers and necessary functions
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\Functions\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\
addpath \Users\HIFU\Documents\MATLAB\PS3000asdk_r10_5_0_32\MATLAB\ps3000a\         

%% Load in PicoStatus values

PicoStatus;

%% Declare variables

global data;

data.TRUE = 1;
data.FALSE = 0;

data.BUFFER_SIZE = 1024*16; % Maximum Buffer size for 3406B is 16384 (1024*16)
data.timebase = 3;  %Highest sampling rate for 3406B is with a time base of 3
                    % sampling rate is (timebase-2)/125E6; time base of 3 
                    % corresponds to a sampling interval of 8 ns
data.oversample = 1;

data.scaleVoltages = data.TRUE;
data.inputRangesmV = [10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];

plotData = data.TRUE;

%% Device Connection

% Create device
ps3000a_obj = icdevice('PS3000a_IC_drv', ''); % Specify serial number as 2nd argument if required.

% Connect device
connect(ps3000a_obj);

% Provide access to enumerations and structures
[methodinfo, structs, enuminfo, ThunkLibName] = PS3000aMFile;

%% Obtain Maximum & Minimum values 

max_val_status = invoke(ps3000a_obj, 'ps3000aMaximumValue')

disp('Max ADC value:');
ps3000a_obj.maxValue

min_val_status= invoke(ps3000a_obj, 'ps3000aMinimumValue')

disp('Min ADC value:');
ps3000a_obj.minValue

%% Channel settings

% Set channel A, the output, and channel C, the trigger channel
channelA = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_A;
channelC = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
channelA_range = enuminfo.enPS3000ARange.PS3000A_200MV;
channelC_range = enuminfo.enPS3000ARange.PS3000A_5V;
analogueOffset = 0;

% Channel settings - create a struct

% Channel A
channelSettings(1).enabled = data.TRUE;
channelSettings(1).DCCoupled = data.TRUE;
channelSettings(1).range = channelA_range;

%Channel C
channelSettings(2).enabled = data.TRUE;
channelSettings(2).DCCoupled = data.TRUE;
channelSettings(2).range = channelC_range;


set_ch_a_status = invoke(ps3000a_obj, 'ps3000aSetChannel', channelA, ...
    channelSettings(1).enabled, channelSettings(1).DCCoupled, ...
    channelSettings(1).range, analogueOffset);

set_ch_c_status = invoke(ps3000a_obj, 'ps3000aSetChannel', channelC, ...
    channelSettings(2).enabled, channelSettings(2).DCCoupled, ...
    channelSettings(2).range, analogueOffset);


%% Set Simple Trigger


enable = data.TRUE;
source = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
threshold = mv2adc(3000, data.inputRangesmV(channelC_range + 1), ps3000a_obj.maxValue);
direction = enuminfo.enPS3000AThresholdDirection.PS3000A_RISING;
delay = 0;              
autoTrigger_ms = 1E4; %amount of time device will wait if no trigger occurs, in this case 10 seconds

trigger_status = invoke(ps3000a_obj, 'ps3000aSetSimpleTrigger', ...
    enable, source, threshold, direction, delay, autoTrigger_ms)


%% Get Timebase

timeIndisposed = 0;
maxSamples = data.BUFFER_SIZE;
timeIntNs = 0;
segmentIndex = 0;

[get_timebase_status, timeIntNs1, maxSamples1] = invoke(ps3000a_obj, 'ps3000aGetTimebase2', ...
        data.timebase, data.BUFFER_SIZE, ...
        timeIntNs, data.oversample, maxSamples, segmentIndex);

%% Setup Number of Captures and Memory Segments

nCaptures = TRACENUM; 

% Segment the memory
[mem_segments_status, maxSamples] = invoke(ps3000a_obj, 'ps3000aMemorySegments', ...
    nCaptures);

% Set the number of captures
num_captures_status = invoke(ps3000a_obj, 'ps3000aSetNoOfCaptures', nCaptures);

%% Run Block

preTriggerSamples = data.BUFFER_SIZE/8; % want to capture a few 
                                        % preTrigger samples prior to 
                                        % trigger firing to see the
                                        % beginning and end of signal
postTriggerSamples = data.BUFFER_SIZE - preTriggerSamples;
segmentIndex = 0;

% Prompt to press a key to begin capture-- might not be necessary to
% include this step because data acquiring should occur without user input
% input_str = input('Press ENTER to begin data collection.', 's');


% Run block and retry if power source not set correctly
retry = 1;

while retry == 1
    
    [run_block_status, timeIndisposedMs] = invoke(ps3000a_obj, 'ps3000aRunBlock', ...
        preTriggerSamples, postTriggerSamples, data.timebase, ...
        data.oversample, segmentIndex)

    % Check power status
    if run_block_status ~= PicoStatus.PICO_OK

        if (run_block_status == PicoStatus.PICO_POWER_SUPPLY_CONNECTED || ...
                run_block_status == PicoStatus.PICO_POWER_SUPPLY_NOT_CONNECTED || ...
                run_block_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

            %change_power_src_status = invoke(ps3000a_obj, 'ChangePowerSource', run_block_status)
            change_power_src_status = ps3000aChangePowerSource(ps3000a_obj, run_block_status)

        else

            % Display error code in Hexadecimal
            fprintf('ps3000aRunBlock status: 0x%X', run_block_status);

        end

    else

        retry = 0;

    end
    
end

% Confirm if device is ready
[status, ready] = invoke(ps3000a_obj, 'ps3000aIsReady')

while ready == 0
   
    [status, ready] = invoke(ps3000a_obj, 'ps3000aIsReady');
    pause(1);
end

fprintf('Ready: %d\n', ready);
disp('Capture complete.');
%% Get Number of Captures

[num_captures_status, nCompleteCaptures] = invoke(ps3000a_obj, 'ps3000aGetNoOfCaptures');

% Only show blocks that were captured

nCaptures = nCompleteCaptures;

%% Set Data Buffer and Get Values

channelA_range = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_A;
channelC_range = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
buffer_length = preTriggerSamples + postTriggerSamples;
buffer_ratio_mode = enuminfo.enPS3000ARatioMode.PS3000A_RATIO_MODE_NONE;

pBufferChA = libpointer('int16Ptr', zeros(buffer_length, nCompleteCaptures));
pBufferChC = libpointer('int16Ptr', zeros(buffer_length, nCompleteCaptures));
% Obtain data values for each capture, setting the data buffer in turn.
for i = 1 : nCaptures
    
    fprintf('Capture %d:\n', i);
    
    temp_bufferA = libpointer('int16Ptr', zeros(buffer_length, 1));
    temp_bufferC = libpointer('int16Ptr', zeros(buffer_length, 1));
    
    status_set_db = invoke(ps3000a_obj, 'ps3000aSetDataBuffer', ... 
        channelA_range, temp_bufferA, ...
        buffer_length, i - 1, buffer_ratio_mode);
    
     


    
    channelC = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
    status_set_dbC = invoke(ps3000a_obj, 'ps3000aSetDataBuffer', ... 
        channelC_range, temp_bufferC, ...
        buffer_length, i - 1, buffer_ratio_mode);
    
  

    startIndex = 0;
    downSampleRatio = 1;
    downSampleRatioMode = enuminfo.enPS3000ARatioMode.PS3000A_RATIO_MODE_NONE;
    overflow = 0;

    % Get Values
    
    [get_values_status, numSamples, overflow] = invoke(ps3000a_obj, ...
        'ps3000aGetValues', startIndex, ...
        buffer_length, downSampleRatio, downSampleRatioMode, ...
        i - 1, overflow)
    
    if(get_values_status ~= PicoStatus.PICO_OK)
    
        % Check if Power Status issue
        if(get_values_status == PicoStatus.PICO_POWER_SUPPLY_CONNECTED || ...
            get_values_status == PicoStatus.PICO_POWER_SUPPLY_NOT_CONNECTED || ...
                get_values_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

            if(get_values_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

                pwr_status = ps3000aChangePowerSource(ps3000a_obj, get_values_status)
                %pwr_status = invoke(ps3000a_obj, 'ChangePowerSource', get_values_status);

            else

                fprintf('Power Source Changed. Data collection aborted.\n');
                plotData = data.FALSE;

            end

        else

            fprintf('ps3000aGetValues status: 0x%X', get_values_status);
            plotData = data.FALSE;

        end
        
    else
        
        fprintf('Assigning data to buffer.\n\n')
        pBufferChA.value(:, i) = temp_bufferA.value(:, 1);
        pBufferChC.value(:, i) = temp_bufferC.value(:, 1);

    end

end

%% Stop the device

stop_status = invoke(ps3000a_obj, 'ps3000aStop');

%% Convert data values to milliVolt values

% disp('Converting data to milliVolts...')
% 
voltage_range_chA = data.inputRangesmV(channelSettings(1).range + 1);
voltage_range_chC = data.inputRangesmV(channelSettings(2).range + 1);
% 
% % Buffers to hold data values
% 
buffer_a = get(pBufferChA, 'Value');
buffer_c = get(pBufferChC, 'Value');


buffer_a_mv = zeros(numSamples, nCaptures);
buffer_c_mv = zeros(numSamples, nCaptures);

buffer_a_mv = adc2mv(buffer_a, voltage_range_chA, ps3000a_obj.maxValue);
    
buffer_c_mv = adc2mv(buffer_c, voltage_range_chC, ps3000a_obj.maxValue);

% for m = 1 : nCaptures
%     
%     for n = 1 : numSamples
% 
%         buffer_a_mv(n, m) = adc2mv(buffer_a(n, m), voltage_range_chA, ps3000a_obj.maxValue);
%     
%         buffer_c_mv(n, m) = adc2mv(buffer_c(n, m), voltage_range_chC, ps3000a_obj.maxValue);
%     
%     end
%     
% end

t_ns = double(timeIntNs1) * double([0: downSampleRatio : numSamples - 1]);
t = t_ns/1E3; % puts time values in microseconds

% save 110414_acoustic_profile_skull_530khz_z0 buffer_a_mv buffer_c_mv t nCaptures numSamples

save 110414_acoustic_profile_skull_530khz_z0  buffer_a_mv buffer_c_mv buffer_a buffer_c t nCaptures numSamples


%% disconnect the device
disconnect(ps3000a_obj);
 
end 