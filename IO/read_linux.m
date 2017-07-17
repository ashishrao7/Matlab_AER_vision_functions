function [TD, EM, others] = read_linux(filename)
% [TD, EM] = read_linux(filename)
% Reads in data from a binary file generated by the ATIS linux framework
%
% TAKES IN:
%   'filename'
%       A string specifying the name of the file to be read. Typical filename
%       is "0000.val" if generated by the ATIS GUI
%
% RETURNS:
%   'TD'
%       A struct of "Temporal Difference" (TD) events with format
%           TD.x =  pixel X locations, strictly positive integers only (TD.x>0)
%           TD.y =  pixel Y locations, strictly positive integers only (TD.y>0)
%           TD.p =  event polarity. TD.p = 0 for OFF events, TD.p = 1 for ON
%                   events
%           TD.ts = event timestamps in microseconds
%
%   EM IS NOT YET IMPLEMENTED 'EM'
%       A struct of grayscale "Exposure Measurement" events (EM events) with
%       format:
%           EM.x =  pixel X locations, strictly positive integers only (EM.x>0)
%           EM.y =  pixel Y locations, strictly positive integers only (EM.y>0)
%           EM.p =  event polarity. EM.p = 0 for first threshold, TD.p = 1 for
%                   second threshold
%           EM.ts = event timestamps in microseconds
%
% If reading in data from the Windows GUI (.val files), use "readAER"
% instead
%
% If reading in datasets (N-Caltech101 or N-MNIST) use the functions
% included with the dataset instead.
%
% written by Garrick Orchard - Jan 2016
% garrickorchard@gmail.com
%%
videoData = fopen(filename);

%% is the first line a header or a version specifier?
temp = fgetl(videoData);
if temp(1) == '#'
    file_version = 0;
    disp(temp)
elseif temp(1) == 'v'
    file_version = str2double(temp(2:end));
end
fprintf('File is version %i\n', file_version);

%% skip through the rest of the comments
file_position = ftell(videoData); %remember the current position before reading in the new line
isContinue = 1;
while isContinue
    temp = fgetl(videoData);
    if isempty(temp)
        isContinue = 0;
        file_position = ftell(videoData); %remember the current position before reading in the new line
    elseif temp(1) == '#'
        disp(temp)
        file_position = ftell(videoData); %remember the current position before reading in the new line
    else
        isContinue = 0;
    end
end
fseek(videoData, file_position, 'bof'); %rewind back to the start of the first non-comment line

%% get the sensor resolution
if file_version == 0
    resolution = [304,240];
else
    resolution = fread(videoData, 2, 'uint16');
    fgetl(videoData);
end
fprintf('Resolution is [%i, %i]\n', resolution(1), resolution(2));
%fgetl(videoData);
% start_offset = ftell(videoData);
%
% total_events = 0;
% %make the ATIS interface write the final number of events at the end of the
% %file so we can avoid this procedure
% while ~feof(videoData)
%     num_events = fread(videoData, 1, 'int32'); %number of bytes in this packet
%     if ~feof(videoData)
%         fseek(videoData, 8+8*num_events, 'cof');
%         total_events = total_events + num_events;
%     end
% end
raw_data_buffer = uint8(fread(videoData));
%initialize TD struct
total_events = length(raw_data_buffer);
TDtemp.x = zeros(1,total_events, 'uint16');
TDtemp.y = zeros(1,total_events, 'uint16');
TDtemp.p = zeros(1,total_events, 'uint8');
TDtemp.ts = zeros(1,total_events, 'uint32');
TDtemp.type = inf*ones(1,total_events, 'uint8');
%TD_indices = logical(zeros(1,total_events));
%fseek(videoData, start_offset, 'bof');

%packet_num = 1;
%read one packet at a time until the end of the file is reached
total_events = 1;
buffer_location = 1;
while buffer_location < length(raw_data_buffer)
    num_events = bitshift(uint32(raw_data_buffer(buffer_location+3)), 24) + bitshift(uint32(raw_data_buffer(buffer_location+2)), 16) + bitshift(uint32(raw_data_buffer(buffer_location+1)), 8) + uint32(raw_data_buffer(buffer_location));
    %fprintf('%d, %d, %d, %d, numEvents: %d\n', raw_data_buffer(buffer_location+3), raw_data_buffer(buffer_location+2), raw_data_buffer(buffer_location+1), raw_data_buffer(buffer_location), num_events);
    buffer_location = buffer_location +4;
    start_time = bitshift(uint32(raw_data_buffer(buffer_location+3)), 24) + bitshift(uint32(raw_data_buffer(buffer_location+2)), 16) + bitshift(uint32(raw_data_buffer(buffer_location+1)), 8) + uint32(raw_data_buffer(buffer_location));
    if file_version ~= 0
        start_time = bitshift(start_time, 16);
    end
    
    buffer_location = buffer_location + 8; %skip the end_time
    
    type = raw_data_buffer(buffer_location:8:(buffer_location+8*(num_events-1)));
    subtype = raw_data_buffer((buffer_location+1):8:(buffer_location+8*(num_events)));
    y = uint16(raw_data_buffer((buffer_location+2):8:(buffer_location+8*(num_events)+1))) + 256*uint16(raw_data_buffer((buffer_location+3):8:(buffer_location+8*(num_events)+1)));
    x = bitshift(uint16(raw_data_buffer((buffer_location+5):8:(buffer_location+8*(num_events)+4))), 8) + uint16(raw_data_buffer((buffer_location+4):8:(buffer_location+8*(num_events)+3)));
    ts = bitshift(uint32(raw_data_buffer((buffer_location+7):8:(buffer_location+8*(num_events)+6))), 8) + uint32(raw_data_buffer((buffer_location+6):8:(buffer_location+8*(num_events)+5)));
    
    buffer_location = buffer_location + num_events*8;
    ts = ts + start_time;
    %packet_num = packet_num + 1;
    if file_version == 0
        overflows = find(type == 2);
        for i = 1:length(overflows)
            ts(overflows(i):end) = ts(overflows(i):end) + 65536;
        end
    end
    
    TDtemp.type(total_events:(total_events+num_events-1)) = type;
    TDtemp.x(total_events:(total_events+num_events-1)) = x;
    TDtemp.y(total_events:(total_events+num_events-1)) = y;
    TDtemp.p(total_events:(total_events+num_events-1)) = subtype;
    TDtemp.ts(total_events:(total_events+num_events-1)) = ts;
    %TDtemp.f(total_events:(total_events+num_events-1)) = type;
    total_events = total_events + num_events;
end

clear raw_data_buffer type x y subtype ts

fclose(videoData);
TDtemp = SortOrder(TDtemp);

TDtemp = RemoveNulls(TDtemp, isinf(TDtemp.type));

TD = RemoveNulls(TDtemp, (TDtemp.type ~= 0) & (TDtemp.type ~=3));
TD.x = double(TD.x+1);
TD.y = double(TD.y+1);
TD.p = double(TD.p+1);
TD.ts = double(TD.ts);

% memory optimization
TDtemp = RemoveNulls(TDtemp, (TDtemp.type ~= 0) & (TDtemp.type ==3));

% memory optimization
EM = RemoveNulls(TDtemp, (TDtemp.type ~= 1));
EM.x = double(EM.x +1);
EM.y = double(EM.y +1);
EM.ts = double(EM.ts);
EM.p = double(EM.p);

TDtemp = RemoveNulls(TDtemp, (TDtemp.type == 1));

others = RemoveNulls(TDtemp, (TDtemp.type < 4));
