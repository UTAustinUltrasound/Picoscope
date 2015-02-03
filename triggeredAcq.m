function waveform = triggeredAcq(TRACENUM, picoDevice, data, enuminfo)
% This function has a hard coded limit for talinmg 

% Invoke max/min values
max_val_status = invoke(picoDevice, 'ps3000aMaximumValue');

disp('Max ADC value:');
picoDevice.maxValue

min_val_status= invoke(picoDevice, 'ps3000aMinimumValue');

disp('Min ADC value:');
picoDevice.minValue

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


set_ch_a_status = invoke(picoDevice, 'ps3000aSetChannel', channelA, ...
    channelSettings(1).enabled, channelSettings(1).DCCoupled, ...
    channelSettings(1).range, analogueOffset);

set_ch_c_status = invoke(picoDevice, 'ps3000aSetChannel', channelC, ...
    channelSettings(2).enabled, channelSettings(2).DCCoupled, ...
    channelSettings(2).range, analogueOffset);


%% Set Simple Trigger


enable = data.TRUE;
source = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
threshold = (2000 * picoDevice.maxValue)/data.inputRangesmV(channelC_range + 1);  % mv2adc(2000, data.inputRangesmV(channelC_range + 1), picoDevice.maxValue);
direction = enuminfo.enPS3000AThresholdDirection.PS3000A_RISING;
delay = 0;              
autoTrigger_ms = 1E4; %amount of time device will wait if no trigger occurs, in this case 10 seconds

trigger_status = invoke(picoDevice, 'ps3000aSetSimpleTrigger', ...
    enable, source, threshold, direction, delay, autoTrigger_ms)


%% Get Timebase

timeIndisposed = 0;
maxSamples = data.BUFFER_SIZE;
timeIntNs = 0;
segmentIndex = 0;

[get_timebase_status, timeIntNs1, maxSamples1] = invoke(picoDevice, 'ps3000aGetTimebase2', ...
        data.timebase, data.BUFFER_SIZE, ...
        timeIntNs, data.oversample, maxSamples, segmentIndex);

%% Setup Number of Captures and Memory Segments

nCaptures = TRACENUM; 

% Segment the memory
[mem_segments_status, maxSamples] = invoke(picoDevice, 'ps3000aMemorySegments', ...
    nCaptures);

% Set the number of captures
num_captures_status = invoke(picoDevice, 'ps3000aSetNoOfCaptures', nCaptures);

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
    
    [run_block_status, timeIndisposedMs] = invoke(picoDevice, 'ps3000aRunBlock', ...
        preTriggerSamples, postTriggerSamples, data.timebase, ...
        data.oversample, segmentIndex)

    % Check power status
    if run_block_status ~= PicoStatus.PICO_OK

        if (run_block_status == PicoStatus.PICO_POWER_SUPPLY_CONNECTED || ...
                run_block_status == PicoStatus.PICO_POWER_SUPPLY_NOT_CONNECTED || ...
                run_block_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

            %change_power_src_status = invoke(picoDevice, 'ChangePowerSource', run_block_status)
            change_power_src_status = ps3000aChangePowerSource(picoDevice, run_block_status)

        else

            % Display error code in Hexadecimal
            fprintf('ps3000aRunBlock status: 0x%X', run_block_status);

        end

    else

        retry = 0;

    end
    
end

% Confirm if device is ready
[status, ready] = invoke(picoDevice, 'ps3000aIsReady')

while ready == 0
   
    [status, ready] = invoke(picoDevice, 'ps3000aIsReady');
    pause(1);
end

fprintf('Ready: %d\n', ready);
disp('Capture complete.');
%% Get Number of Captures

[num_captures_status, nCompleteCaptures] = invoke(picoDevice, 'ps3000aGetNoOfCaptures');

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
    
    status_set_db = invoke(picoDevice, 'ps3000aSetDataBuffer', ... 
        channelA_range, temp_bufferA, ...
        buffer_length, i - 1, buffer_ratio_mode);
    
     


    
    channelC = enuminfo.enPS3000AChannel.PS3000A_CHANNEL_C;
    status_set_dbC = invoke(picoDevice, 'ps3000aSetDataBuffer', ... 
        channelC_range, temp_bufferC, ...
        buffer_length, i - 1, buffer_ratio_mode);
    
  

    startIndex = 0;
    downSampleRatio = 1;
    downSampleRatioMode = enuminfo.enPS3000ARatioMode.PS3000A_RATIO_MODE_NONE;
    overflow = 0;

    % Get Values
    
    [get_values_status, numSamples, overflow] = invoke(picoDevice, ...
        'ps3000aGetValues', startIndex, ...
        buffer_length, downSampleRatio, downSampleRatioMode, ...
        i - 1, overflow)
    
    if(get_values_status ~= PicoStatus.PICO_OK)
    
        % Check if Power Status issue
        if(get_values_status == PicoStatus.PICO_POWER_SUPPLY_CONNECTED || ...
            get_values_status == PicoStatus.PICO_POWER_SUPPLY_NOT_CONNECTED || ...
                get_values_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

            if(get_values_status == PicoStatus.PICO_POWER_SUPPLY_UNDERVOLTAGE)

                pwr_status = ps3000aChangePowerSource(picoDevice, get_values_status)
                %pwr_status = invoke(picoDevice, 'ChangePowerSource', get_values_status);

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

% stop_status = invoke(picoDevice, 'ps3000aStop');

%% Convert data values to milliVolt values

% disp('Converting data to milliVolts...')
% 
voltage_range_chA = data.inputRangesmV(channelSettings(1).range + 1);
voltage_range_chC = data.inputRangesmV(channelSettings(2).range + 1);
% 
% % Buffers to hold data values
% 
waveform.buffer_a = get(pBufferChA, 'Value');
waveform.buffer_c = get(pBufferChC, 'Value');


waveform.buffer_a_mv = zeros(numSamples, nCaptures);
waveform.buffer_c_mv = zeros(numSamples, nCaptures);

waveform.buffer_a_mv = adc2mv(waveform.buffer_a, voltage_range_chA, picoDevice.maxValue);
    
waveform.buffer_c_mv = adc2mv(waveform.buffer_c, voltage_range_chC, picoDevice.maxValue);


t_ns = double(timeIntNs1) * double([0: downSampleRatio : numSamples - 1]);
waveform.t = t_ns/1E3; % puts time values in microseconds

 
end 
