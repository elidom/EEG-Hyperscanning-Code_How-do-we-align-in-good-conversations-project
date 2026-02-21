%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Step 06)
%
%  Authors: Marcos E. Domínguez Arriola & Peter C.H. Lam
%  Repository: https://github.com/elidom/Hyperscanning-Scripts_Engaging-Conversations-Project/tree/main
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    06 - Adding offline event markers for speaking turns and manual masking
%
%  Notes:
%    - Requires access to the audio recordings of conversations and CSV
%    files containing timing information (see audio preprocessing).
%    - Audio alignment to EEG signals is done via cross-correlation of
%    amplitude envelopes. Requires manual confirmation of cross-correlation alignment.
%    - Manual masking intervals are stored within the EEG structure.
%    - Dyad 18 contains a hard-coded event correction.
%
%  ------------------------------------------------------------------------

clear, clc, close all

% Navigate to the root folder of the data
tmp = matlab.desktop.editor.getActive; % Get the current active file
current_dir = fileparts(tmp.Filename); % Get the directory of the current file
up_one_level = fullfile(current_dir, '..');
eeg_dir = fullfile(up_one_level);
cd(fullfile(eeg_dir)); 

% Select files to be processed
[file_name, file_path] = uigetfile('05_Merged\\*.set',  'set Files (*.set*)','MultiSelect','off');

% Get sub and cond str
dyadID = strrep(file_name, '_merged.set', '');

EEG = pop_loadset(file_name, file_path);

%% Add offline markers and replace StimTrack samples

% Part 1: Fetch conversation event latencies
selectedEvents = struct('type', {}, 'latency', {});
index = 1;

% Loop through all events
for i = 1:length(EEG.event)
    evType = EEG.event(i).type;
    
    % Check if the event type starts with 'S'
    if startsWith(evType, 'S')
        % Use a regular expression to extract the numeric part
        numStr = regexp(evType, '\d+', 'match');
        if ~isempty(numStr)
            numVal = str2double(numStr{1});
            % Check if the numeric value is less than 50
            if numVal < 50
                selectedEvents(index).type = numVal;
                selectedEvents(index).latency = EEG.event(i).latency;
                index = index + 1;
            end
        end
    end
end

if dyadID == "hyperEngaging_dyad_18" % this dyad needs some fixing.
    selectedEvents(1).latency = selectedEvents(25).latency;    
    selectedEvents(2).latency = selectedEvents(26).latency;
    selectedEvents(1).type    = 31; selectedEvents(2).type = 41;
end

% Part 2: Organize in a tidy format
tidyEvents = struct('type', {}, 'n', {}, 'code', {}, 'start', {}, 'end', {});
index = 1;

possible_types = ["low_interest", "high_interest"];

blocks = [1 1 2 2 3 3 4 4 5 5 6 6]; 

for i = 1:12
    block = blocks(i);
    curr_event = selectedEvents(index).type;
    type = (curr_event > 10 && curr_event < 20) + 1; % gives 1+1 when code is ~10, 0+1 when ~30 
    tidyEvents(i).type = possible_types(type);
    tidyEvents(i).n = block;
    tidyEvents(i).code  = curr_event;
    tidyEvents(i).start = selectedEvents(index).latency;
    tidyEvents(i).end = selectedEvents(index+1).latency;
        
    if ~selectedEvents(index+1).type == curr_event + 10
        error('Start and end event numbers do not match during iteration %d. Stopping.', i);
    end

    index = index + 2;
end

% Part 3: fetch audio data, find point of highest cross correlation with
% each trial, and add offline markers based on csv

% eventData = readtable('00_Event_Data\pilot_02\low_interest_1_knitting.csv');
N = size(tidyEvents,2);
dnum = dyadID(end-1:end);
csvDir = ['..\Audio\06_as_csv\Dyad' dnum '\'];
wavDir = ['..\Audio\00_Clean_Audio_Files\dyad' dnum '\'];

labels  = {EEG.chanlocs.labels};
auxChans = find(contains(labels, 'Aux', 'IgnoreCase', true));

if isempty(auxChans)
    error('Could not find Stimtrack/Aux channel.');
end

auxChan = auxChans(1);

% initialize record of shifts for later segmenting the audio files.
shiftlist = struct('wav_file', {}, 'shift', {});

for i = 1:12 
    
    partialFileName = [char(tidyEvents(i).type) '_' num2str(tidyEvents(i).n)];
    searchPath = fullfile(wavDir, [partialFileName, '*.wav']);
    fileList = dir(searchPath);

    if ~isempty(fileList)
        audioFileName = fileList(1).name;
    else
        error("Something went wrong.") 
    end
    
    shiftlist(i).wav_file = audioFileName;

    % Load Audio
    [wav, fs] = audioread(fullfile(wavDir, audioFileName));
    
    % Resample
    wavt = wav';
    wav_resampled = resample(wavt, 500, 44100);               
    wav_resampled = wav_resampled - mean(wav_resampled);      
    wav_resampled = wav_resampled / max(abs(wav_resampled));  
    
    % Compute amplitude envelope
    wav_env = mTRFenvelope(wav, fs, 500)'; 

    % Fetch Stimtrack 
    start_lat = tidyEvents(i).start;
    end_lat = tidyEvents(i).end;

    stimtrack = EEG.data(auxChan, start_lat:end_lat);
    stimtrack = stimtrack - mean(stimtrack);                   
    stimtrack = stimtrack / max(abs(stimtrack));               

    stim_env = mTRFenvelope(stimtrack, 500, 500);

    % Adjust the length of wav if necessary
    % The envelope may be one sample shorter than the waveform
    if length(wav_resampled) > length(wav_env)
        l = length(wav_resampled);
        wav_resampled = wav_resampled(1:l-1);
    end

    % Compute cross-correlation between EEG audio channel and audio waveform
    wav_env2  = zscore(wav_env(:));
    stim_env = zscore(stim_env(:));

    [r, lags] = xcorr(stim_env, wav_env2);

    % Create figure
    figure;
    plot(lags, r);
    xlabel('Lags');
    ylabel('r');
    title(sprintf('Iteration %d: Accept?', i));

    btn = uicontrol('Style', 'pushbutton', 'String', 'Accept', ...
        'Position', [20 20 100 40], ...
        'Callback', 'uiresume(gcbf)');

    uiwait(gcf);
    close(gcf);
    disp(['Iteration ' num2str(i) ' accepted.']);

    % Find the lag with the maximum absolute correlation
    [larger_r, idx] = max(abs(r));
    shift = lags(idx);
    disp(['Shift: ' num2str(shift) ' Samples (' num2str(shift/500) ' s)'])
    
    shiftlist(i).shift = shift/500;

    % A positive shift means the WAV is delayed with respect to the
    % StimTrack data. Thus, my event markers should be at T + shift.
    
    % Replace StimTrack data with Amplitude Envelope
    st_length = length(stimtrack);
    wv_length = length(wav_env);
    if shift > 0
        
        if shift + wv_length > st_length
            envLim = wav_env(1:(st_length-shift+1)); % trim envelope
            stimtrack(shift:end) = envLim;           % replace data with envelope
            stimtrack(1:shift-1) = 0;                % rst with zeros
        else
            stimtrack(shift:(shift+wv_length-1)) = wav_env; 
            stimtrack(1:shift-1) = 0;
            stimtrack(shift+wv_length:end) = 0;
        end
    else
        envLim = wav_env(abs(shift):end);
        if length(envLim) > st_length
            stimtrack(1:length(stimtrack)) = envLim(1:length(stimtrack)); 
        else
            warning('This else statement has only been partially tested, at iteration %d.', i);
            stimtrack(1:length(envLim)) = envLim; % (warning: partially tested)
            stimtrack(length(envLim)+1:end) = 0;
        end
    end
    
    EEG.data(auxChan, start_lat:end_lat) = stimtrack;
    
    % Load Praat TextGrid Data
    fileName = dir(fullfile(csvDir, ['dyad' dnum '_' partialFileName '*']));

    if isempty(fileName)
        error('No files found matching the pattern: %s', partialFileName);
    else
        eventData = readtable(fullfile(csvDir, fileName.name));
    end

    % Transform text grid (keep relevant rows and convert latencies)
    speakingLatencies = struct('speaker', {}, 'start', {}, 'end', {});
    
    % 2. filter to keep only rows of speaking turns
    keep = {'SpeakerA', 'SpeakerB'};
    matches = false(height(eventData), 1);
    for j = 1:length(keep)
         matches = matches | contains(eventData.tier, keep{j});
    end

    filteredEvents = eventData(matches, :);
    
    % 3. Loop through rows and populate new struct
    for j = 1:height(filteredEvents)
        speakingLatencies(j).speaker = char(filteredEvents{j,"tier"});
        speakingLatencies(j).start   = filteredEvents{j,"tmin"} * 500 + shift; 
        speakingLatencies(j).end     = filteredEvents{j,"tmax"} * 500 + shift;
    end
    
    endsb40 = find([speakingLatencies.end]<0);
    if ~isempty(endsb40)
        warning('An event ends before 0. Figure out how to handle this before continuing.')
        speakingLatencies(endsb40) = [];
        % probably just delete that row.
    end

    startsb40 = find([speakingLatencies.start]<0);
    if ~isempty(startsb40)
        if length(startsb40) > 1
            error('Multiple events start befoer 0. Figure out how to handle this before continuing.');
        else
            speakingLatencies(startsb40).start = 0;
        end
    end

    % Add event markers to the EEG set
    for j = 1:size(speakingLatencies,2)
        spkr = speakingLatencies(j).speaker;

        % Start marker
        marker_latency_start = speakingLatencies(j).start; 
        if spkr == "SpeakerA"
            newMarker.type = 'S 91';   
        elseif spkr == "SpeakerB"
            newMarker.type = 'S 95';
        else
            error('Something went wrong.')
        end

        newMarker.latency = start_lat + marker_latency_start;
        newMarker.duration = 1; 
        newMarker.channel = 0;
        newMarker.bvmknum = [];
        newMarker.visible = [];
        newMarker.code = 'Stimulus';
        newMarker.urevent = [];
        newMarker.bvtime = [];

        EEG.event(end+1) = newMarker;

        % End marker
        marker_latency_end = speakingLatencies(j).end; 
        if spkr == "SpeakerA"
            newMarker.type = 'S 92';   
        elseif spkr == "SpeakerB"
            newMarker.type = 'S 96';
        else
            error('Something went wrong.')
        end

        newMarker.latency = start_lat + marker_latency_end;
        newMarker.duration = 1; 
        newMarker.channel = 0;
        newMarker.bvmknum = [];
        newMarker.visible = [];
        newMarker.code = 'Stimulus';
        newMarker.urevent = [];
        newMarker.bvtime = [];

        EEG.event(end+1) = newMarker;
    end
end

% Update the EEG structure (this ensures event consistency)
EEG = eeg_checkset(EEG, 'eventconsistency');

% save shiftlist
Tshift = struct2table(shiftlist);
shiftlistfilename = ['shiftlists/shiftlist_' dyadID '.csv'];
writetable(Tshift, shiftlistfilename);

%% delete unevent data

oneSec = EEG.srate;

% Initialize matrix to store rejection intervals.
% Each row will be [startSample, endSample]
rejIntervals = [];

% number of events
numEvents = length(EEG.event);

for i = 1:numEvents
    % Extract the numeric part of the event type.
    % For example, if the event type is 'T 25' or 'S 41'
    evTypeStr = EEG.event(i).type;
    numStr = regexp(evTypeStr, '\d+', 'match');
    if isempty(numStr)
        continue; 
    end
    evVal = str2double(numStr{1});
    
    % Check if this event is marks the end of a trial
    if (evVal >= 20 && evVal <= 29) || ...
       (evVal >= 40 && evVal <= 49) || ...
       (evVal >= 60 && evVal <= 69) || ...
       (evVal >= 80 && evVal <= 89)

        % Define the start of the rejection interval:
        startRej = EEG.event(i).latency + oneSec;  % one second AFTER the trigger
        
        % Now look for the next event that marks the beginning of a trial:
        foundBoundary = false;
        nextIdx = i + 1;
        while nextIdx <= numEvents
            evTypeStr2 = EEG.event(nextIdx).type;
            numStr2 = regexp(evTypeStr2, '\d+', 'match');
            if ~isempty(numStr2)
                evVal2 = str2double(numStr2{1});
                if (evVal2 >= 10 && evVal2 <= 19) || ...
                   (evVal2 >= 30 && evVal2 <= 39) || ...
                   (evVal2 >= 50 && evVal2 <= 59) || ...
                   (evVal2 >= 70 && evVal2 <= 79)
                    % Found one.
                    endRej = EEG.event(nextIdx).latency - oneSec; % one second BEFORE this event
                    foundBoundary = true;
                    break;
                end
            end
            nextIdx = nextIdx + 1;
        end
        
        % If good, save the interval.
        if foundBoundary && endRej > startRej
            rejIntervals = [rejIntervals; [startRej, endRej]];
        end
    end
end

% Display the intervals to be rejected (in sample points)
disp('Rejection intervals (in samples):');
disp(rejIntervals);

% Now automatically reject those segments from the EEG data.
% eeg_eegrej takes a matrix with rows of [start end] sample indices.
EEG = eeg_eegrej(EEG, rejIntervals);

disp(' # - - - - - Unevent deletion done. - - - - - #')


%% Step 06 Manual Masking

ALLEEG = EEG;
CURRENTSET = 1;

% Change set name
EEG = pop_editset(EEG, 'setname', strcat(dyadID, '_MR'));

% Manual masking
eegplot(EEG.data([1:33 34:end],:), 'srate', EEG.srate, 'title', 'Manual masking (Click "Accept And Close" when Finished (NOT REJECT)!)', 'events', EEG.event);
uiwait(gcf);

% Extract only the start and end times from TMPREJ
maskedIntervals = TMPREJ(:,1:2);

% Store mask in EEG structure 
EEG.maskedIntervals = maskedIntervals;

% Wait to continue after check...
input('Done manual masking for this subject? Press enter to save')

% Save dataset
EEG = pop_editset(EEG, 'setname', strcat(dyadID, '_merged'));
EEG = pop_saveset(EEG, strcat(dyadID, '_MR.set'), '06_MR\\');